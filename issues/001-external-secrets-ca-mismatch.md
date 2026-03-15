# Issue 001: External-Secrets CA Certificate Mismatch

**Date**: 2026-03-15 **Status**: Open **Severity**: High - blocks all secret
synchronization

## Summary

All ExternalSecrets are failing with `SecretSyncedError` due to TLS certificate
verification failure. The root cause is an architectural issue in how the
ClusterSecretStore references its CA certificate.

## How cert-manager Certificate Issuance Works

### The Certificate Chain

cert-manager creates a PKI (Public Key Infrastructure) hierarchy:

```
┌─────────────────────────────────────────────────────────────────────┐
│  ClusterIssuer: bitwarden-bootstrap-issuer                         │
│  Type: SelfSigned                                                   │
│  Purpose: Bootstrap a CA certificate from nothing                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ issues
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Certificate: bitwarden-bootstrap-ca                                │
│  isCA: true                                                         │
│  secretName: bitwarden-ca-keypair                                   │
│  Purpose: The root CA - contains the private key used to sign      │
│           all leaf certificates                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ used by
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  ClusterIssuer: bitwarden-certificate-issuer                        │
│  Type: CA                                                           │
│  secretName: bitwarden-ca-keypair                                   │
│  Purpose: Issues leaf certificates signed by the CA                 │
└─────────────────────────────────────────────────────────────────────┘
                    │                           │
                    │ issues                    │ issues
                    ▼                           ▼
┌────────────────────────────────┐  ┌────────────────────────────────┐
│ Certificate: bitwarden-tls-certs│  │ Certificate: bitwarden-css-certs│
│ secretName: bitwarden-tls-certs │  │ secretName: bitwarden-css-certs │
│ duration: 168h (7 days)         │  │ duration: 168h (7 days)         │
│ renewBefore: 24h                │  │ renewBefore: 24h                │
│ Purpose: Server TLS for         │  │ Purpose: Client certificate     │
│          bitwarden-sdk-server   │  │          (unused in practice)   │
└────────────────────────────────┘  └────────────────────────────────┘
```

### What cert-manager Puts in Each Secret

When cert-manager creates a secret for a Certificate, it includes three keys:

| Key       | Contents                                              |
| --------- | ----------------------------------------------------- |
| `tls.crt` | The leaf certificate (PEM encoded)                    |
| `tls.key` | The private key for the leaf certificate              |
| `ca.crt`  | **A snapshot of the CA certificate at issuance time** |

**Critical behavior**: The `ca.crt` field is populated once when the certificate
is issued and represents the CA that signed this specific certificate. It is NOT
a live reference to the CA - it's a point-in-time copy.

### The Secret Structure

```yaml
# bitwarden-ca-keypair (the source of truth)
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
data:
  tls.crt: <CA certificate - this IS the CA>
  tls.key: <CA private key - used to sign leaf certs>
  ca.crt:  <same as tls.crt for self-signed CA>

# bitwarden-tls-certs (leaf certificate)
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
data:
  tls.crt: <server certificate, signed by CA>
  tls.key: <server private key>
  ca.crt:  <COPY of CA cert at time of issuance>  ← This can become stale!
```

## Why the CA Certificates Diverged

### Timeline of Events

1. **Initial Setup (Nov 2025)**: All certificates issued with CA version 1
2. **CA Rotation (Jan 2026)**: `bitwarden-bootstrap-ca` renewed (Revision 2)
   - `bitwarden-ca-keypair` now contains a NEW CA keypair
   - Existing leaf cert secrets still have OLD CA in their `ca.crt`
3. **Leaf Cert Renewals (ongoing)**: 7-day rotation cycle
   - Each renewal gets a snapshot of the CURRENT CA
   - But renewals happen at slightly different times
   - After CA rotation, some secrets got new CA, some had old

### Current State (verified by sha256sum)

| Secret                 | ca.crt Hash   | When Captured             |
| ---------------------- | ------------- | ------------------------- |
| `bitwarden-ca-keypair` | `440247b7...` | Current CA (Jan 2026)     |
| `bitwarden-tls-certs`  | `347aaff4...` | Old CA snapshot           |
| `bitwarden-css-certs`  | `e330a619...` | Different old CA snapshot |

All three should contain the same CA certificate, but they don't.

## The Architectural Flaw

### Current Configuration

```yaml
# bootstrap/clustersecretstore.tmpl.yaml (CURRENT - PROBLEMATIC)
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: bitwarden-secretsmanager
spec:
  provider:
    bitwardensecretsmanager:
      bitwardenServerSDKURL: https://bitwarden-sdk-server.external-secrets.svc.cluster.local:9998
      caProvider:
        type: Secret
        name: bitwarden-css-certs # ← References a LEAF certificate secret
        namespace: external-secrets
        key: ca.crt # ← Uses the embedded (potentially stale) CA copy
```

**Problem**: The ClusterSecretStore trusts whatever CA is embedded in
`bitwarden-css-certs`. This is a leaf certificate secret where `ca.crt` is just
a snapshot from when the certificate was last renewed.

Meanwhile, `bitwarden-sdk-server` presents a certificate from
`bitwarden-tls-certs`, which may have a different CA snapshot embedded in it.

### The TLS Handshake Failure

```
external-secrets controller                    bitwarden-sdk-server
         │                                              │
         │──── TLS ClientHello ────────────────────────▶│
         │                                              │
         │◀─── TLS ServerHello + Certificate ───────────│
         │     (cert from bitwarden-tls-certs,          │
         │      signed by CA version X)                 │
         │                                              │
         │ Verify cert against CA from                  │
         │ bitwarden-css-certs ca.crt                   │
         │ (CA version Y)                               │
         │                                              │
         │ X ≠ Y → VERIFICATION FAILED                  │
         │                                              │
         ╳ "certificate signed by unknown authority"    │
```

## Root Cause Fix

### Change ClusterSecretStore to Reference the Canonical CA

Instead of referencing a leaf certificate's embedded CA copy, reference the
actual CA secret directly:

```yaml
# bootstrap/clustersecretstore.tmpl.yaml (FIXED)
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: bitwarden-secretsmanager
spec:
  provider:
    bitwardensecretsmanager:
      bitwardenServerSDKURL: https://bitwarden-sdk-server.external-secrets.svc.cluster.local:9998
      caProvider:
        type: Secret
        name: bitwarden-ca-keypair # ← Reference the ACTUAL CA secret
        namespace: external-secrets
        key: ca.crt # ← This is the authoritative CA certificate
```

**Why this works**:

- `bitwarden-ca-keypair` IS the CA - its `ca.crt`/`tls.crt` is the actual CA
  certificate
- When the CA rotates, this secret is updated directly by cert-manager
- The ClusterSecretStore will always use the current CA
- No dependency on leaf certificate renewal timing

### Why the Current Design is Fragile

The current design has a hidden dependency chain:

```
CA rotates
    │
    ├── bitwarden-ca-keypair updated immediately
    │
    ├── bitwarden-certificate-issuer sees new CA (uses bitwarden-ca-keypair)
    │
    ├── bitwarden-tls-certs renewal (next cycle)
    │   └── Gets new CA in ca.crt
    │   └── bitwarden-sdk-server restarts (reloader)
    │
    └── bitwarden-css-certs renewal (different cycle)
        └── Gets new CA in ca.crt
        └── ClusterSecretStore... doesn't re-validate automatically
        └── external-secrets controller... when does it pick up new CA?
```

The fixed design has a simple dependency:

```
CA rotates
    │
    └── bitwarden-ca-keypair updated
        └── ClusterSecretStore sees new CA immediately
        └── All verifications use correct CA
```

## Code Changes Required

### File: `bootstrap/clustersecretstore.tmpl.yaml`

```diff
 apiVersion: external-secrets.io/v1
 kind: ClusterSecretStore
 metadata:
   name: bitwarden-secretsmanager
 spec:
   provider:
     bitwardensecretsmanager:
       apiURL: https://api.bitwarden.com
       identityURL: https://identity.bitwarden.com
       auth:
         secretRef:
           credentials:
             key: token
             name: bitwarden-access-token
             namespace: external-secrets
       bitwardenServerSDKURL: https://bitwarden-sdk-server.external-secrets.svc.cluster.local:9998
       organizationID: ${BWS_ORG}
       projectID: ${BWS_PROJECT}
       caProvider:
         type: Secret
-        name: bitwarden-css-certs
+        name: bitwarden-ca-keypair
         namespace: external-secrets
         key: ca.crt
```

### File: `k8s/apps/external-secrets/base/helmrelease.yaml`

Add the CA keypair to the reloader annotation so the controller picks up CA
rotations:

```diff
 apiVersion: helm.toolkit.fluxcd.io/v2
 kind: HelmRelease
 metadata:
   name: external-secrets
 spec:
   interval: 30m
   chartRef:
     kind: OCIRepository
     name: external-secrets
   values:
     installCRDs: true
     podAnnotations:
-      secret.reloader.stakater.com/reload: "bitwarden-css-certs"
+      secret.reloader.stakater.com/reload: "bitwarden-ca-keypair"
     bitwarden-sdk-server:
       enabled: true
       podAnnotations:
-        secret.reloader.stakater.com/reload: "bitwarden-css-certs,bitwarden-secrets-manager,bitwarden-secrets-manager-secrets,bitwarden-tls-certs,bitwarden-access-token"
+        secret.reloader.stakater.com/reload: "bitwarden-ca-keypair,bitwarden-tls-certs,bitwarden-access-token"
```

Note: Removed `bitwarden-css-certs` since it's a client certificate that isn't
actually used (the SDK server doesn't require mTLS). Also removed
`bitwarden-secrets-manager` and `bitwarden-secrets-manager-secrets` if they
don't exist or aren't relevant.

## Post-Fix Cleanup Steps

After applying the code changes, you'll need to sync the current state:

1. **Delete the stale leaf certificate secrets** to force re-issuance with
   current CA:

   ```bash
   kubectl delete secret bitwarden-tls-certs bitwarden-css-certs -n external-secrets
   ```

2. **Wait for cert-manager to recreate them**:

   ```bash
   kubectl get certificates -n external-secrets -w
   ```

3. **Verify CA hashes now match**:

   ```bash
   kubectl get secret bitwarden-ca-keypair -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
   kubectl get secret bitwarden-tls-certs -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
   kubectl get secret bitwarden-css-certs -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
   # All three should now show the same hash
   ```

4. **Restart deployments** (or wait for reloader):

   ```bash
   kubectl rollout restart deployment/bitwarden-sdk-server deployment/external-secrets -n external-secrets
   ```

5. **Verify ExternalSecrets recover**:
   ```bash
   kubectl get externalsecrets -A
   # Should show Ready: True for all
   ```

## Why bitwarden-css-certs Exists

Looking at the Certificate definition:

```yaml
# k8s/apps/external-secrets-config/base/bitwarden-self-signed-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: bitwarden-css-certs
spec:
  secretName: bitwarden-css-certs
  dnsNames:
    - bitwarden-secrets-manager.external-secrets.svc.cluster.local
  usages:
    - client auth # ← This is a CLIENT certificate
  issuerRef:
    name: bitwarden-certificate-issuer
```

This appears to be a client certificate (note `usages: [client auth]`) that
would be used for mTLS if the bitwarden-sdk-server required client
authentication. However, the current setup doesn't appear to use mTLS - the SDK
server only requires server TLS (`bitwarden-tls-certs`).

The `bitwarden-css-certs` secret was likely created for potential mTLS use and
then repurposed as a convenient place to get the CA certificate. This was a
mistake because:

1. It's semantically wrong (a client cert secret shouldn't be the CA source)
2. It creates the stale CA problem described above
3. The actual CA source (`bitwarden-ca-keypair`) is available and correct

## Affected Components

| Component                      | Current Status            | After Fix              |
| ------------------------------ | ------------------------- | ---------------------- |
| external-secrets controller    | Cannot verify server cert | Will use correct CA    |
| bitwarden-sdk-server           | Serving valid cert        | No change needed       |
| ClusterSecretStore             | Points to stale CA        | Points to canonical CA |
| All ExternalSecrets            | SecretSyncedError         | Should recover         |
| Downstream Flux Kustomizations | Blocked                   | Should reconcile       |
