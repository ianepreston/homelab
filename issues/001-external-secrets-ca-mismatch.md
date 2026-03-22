# Issue 001: External-Secrets ClusterSecretStore CA Reference

**Date**: 2026-03-16
**Status**: Open
**Severity**: High - blocks all secret synchronization

## Summary

The ClusterSecretStore `bitwarden-secretsmanager` cannot initialize because it
references the CA secret `bitwarden-ca-keypair` in the wrong namespace. The
secret exists in `cert-manager` namespace, but the ClusterSecretStore is
configured to look for it in `external-secrets` namespace.

## Current Symptoms

```
$ kubectl get clustersecretstores
NAME                       AGE    STATUS                  READY
bitwarden-secretsmanager   109m   InvalidProviderConfig   False
```

```
$ kubectl describe clustersecretstore bitwarden-secretsmanager
Events:
  Warning  InvalidProviderConfig  ...  could not create SdkClient: error creating
  https client: failed to get cert from secret: failed to resolve secret key ref:
  cannot get Kubernetes secret "bitwarden-ca-keypair" from namespace
  "external-secrets": secrets "bitwarden-ca-keypair" not found
```

## Root Cause

### Where the CA Secret Actually Lives

The CA Certificate is defined in
`k8s/apps/external-secrets-config/base/bitwarden-self-signed-cert.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: bitwarden-bootstrap-ca
  namespace: cert-manager          # <-- Certificate is in cert-manager namespace
spec:
  secretName: bitwarden-ca-keypair # <-- Secret created in SAME namespace
  isCA: true
  ...
```

cert-manager creates the secret in the same namespace as the Certificate
resource. Therefore `bitwarden-ca-keypair` exists in `cert-manager`, not
`external-secrets`.

**Verified state:**
```
$ kubectl get secret bitwarden-ca-keypair -n cert-manager
NAME                   TYPE                DATA   AGE
bitwarden-ca-keypair   kubernetes.io/tls   3      110m

$ kubectl get secret bitwarden-ca-keypair -n external-secrets
Error from server (NotFound): secrets "bitwarden-ca-keypair" not found
```

### Why the ClusterIssuer Works

The `bitwarden-certificate-issuer` ClusterIssuer correctly finds the CA:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: bitwarden-certificate-issuer
spec:
  ca:
    secretName: bitwarden-ca-keypair
```

ClusterIssuers look for CA secrets in the `cert-manager` namespace by default
(this is cert-manager's documented behavior for cluster-scoped issuers). That's
why leaf certificates in `external-secrets` namespace are successfully issued.

### The Incorrect Configuration

The previous fix (commit 5ca0bcd) correctly changed the ClusterSecretStore to
reference the canonical CA secret instead of a leaf certificate. However, it
kept the namespace as `external-secrets`:

```yaml
# bootstrap/clustersecretstore.tmpl.yaml (CURRENT - BROKEN)
caProvider:
  type: Secret
  name: bitwarden-ca-keypair
  namespace: external-secrets  # <-- WRONG: secret is in cert-manager
  key: ca.crt
```

## Architecture Overview

```
cert-manager namespace                    external-secrets namespace
=======================                   ==========================

Certificate: bitwarden-bootstrap-ca       Certificate: bitwarden-tls-certs
  |                                         |
  v (creates)                               v (creates)
Secret: bitwarden-ca-keypair              Secret: bitwarden-tls-certs
  |                                           |
  | (used by)                                 | (mounted by)
  v                                           v
ClusterIssuer:                            bitwarden-sdk-server
bitwarden-certificate-issuer                  |
  |                                           | (serves TLS to)
  | (issues)                                  v
  +-------------------------------→       external-secrets controller
                                              |
                                              | (needs CA to verify)
                                              v
                                          ClusterSecretStore
                                          (looking in wrong namespace!)
```

## Resolution

### Required Change

Update `bootstrap/clustersecretstore.tmpl.yaml` to reference the correct
namespace:

```diff
 caProvider:
   type: Secret
   name: bitwarden-ca-keypair
-  namespace: external-secrets
+  namespace: cert-manager
   key: ca.crt
```

### Full Corrected Configuration

```yaml
# bootstrap/clustersecretstore.tmpl.yaml
---
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
        name: bitwarden-ca-keypair
        namespace: cert-manager      # Correct namespace
        key: ca.crt
```

### Post-Fix Verification

After applying the fix and re-bootstrapping:

```bash
# ClusterSecretStore should become Ready
kubectl get clustersecretstores

# ExternalSecrets should sync
kubectl get externalsecrets -A
```

## Why This Wasn't Caught Earlier

The original configuration used `bitwarden-css-certs` which is a leaf
certificate that DOES exist in `external-secrets` namespace. The previous fix
correctly identified that referencing a leaf certificate's embedded `ca.crt` is
architecturally fragile (it's a point-in-time snapshot that can become stale).

The fix correctly changed to reference the canonical CA secret
`bitwarden-ca-keypair`, but failed to account for the namespace difference:

| Secret                | Namespace          | Purpose              |
| --------------------- | ------------------ | -------------------- |
| `bitwarden-ca-keypair`| `cert-manager`     | The actual CA        |
| `bitwarden-tls-certs` | `external-secrets` | Server cert for SDK  |
| `bitwarden-css-certs` | `external-secrets` | Unused client cert   |

## Alternative Consideration

An alternative approach would be to move the CA Certificate to `external-secrets`
namespace. However, this is not recommended because:

1. cert-manager ClusterIssuers expect CA secrets in `cert-manager` namespace by
   default
2. The current setup follows cert-manager conventions
3. ClusterSecretStore can reference secrets in any namespace

The simpler fix is to update the namespace reference in the ClusterSecretStore.
