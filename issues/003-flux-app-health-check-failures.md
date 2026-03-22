# Issue 003: Flux Application Health Check Failures

**Date**: 2026-03-22 **Status**: Open **Severity**: Critical - blocks deployment
of 3 applications

## Summary

Three Flux applications (actualbudget, authentik, miniflux) are failing health
checks due to persistent volume provisioning issues. The root causes are:

1. **actualbudget**: PVC size below Longhorn's minimum XFS filesystem
   requirement
2. **authentik & miniflux**: Invalid StorageClass parameter incompatible with
   Longhorn v1.11.0

All failures have existed for 6+ days with continuous retry loops consuming
cluster resources.

## Current Symptoms

### Failed Kustomizations

```
$ flux get kustomizations -A | grep False
flux-system actualbudget  False  health check failed: failed early due to stalled resources: [Deployment/actualbudget/actualbudget status: 'Failed']
flux-system authentik     False  health check failed: failed early due to stalled resources: [HelmRelease/authentik/authentik status: 'Failed']
flux-system apps-dev      False  dependency 'flux-system/platform-dev' is not ready (secondary failure)
flux-system miniflux      Unknown Reconciliation in progress (stuck for 6d5h)
```

### Failed HelmReleases

```
$ flux get helmreleases -A | grep False
authentik  authentik  False  timeout waiting for: [Deployment/authentik/authentik-server status: 'InProgress',
                             Deployment/authentik/authentik-worker status: 'InProgress']
```

### Pending PVCs

```
$ kubectl get pvc -A | grep Pending
actualbudget  actualbudget-pvc       Pending  longhorn-default             6d5h
authentik     authentik-cnpg-db-1    Pending  longhorn-cnpg-strict-local   6d5h
miniflux      miniflux-cnpg-db-1     Pending  longhorn-cnpg-strict-local   6d5h
```

## Root Cause Analysis

### Issue 1: actualbudget - Volume Size Too Small

**Location**: `k8s/apps/actualbudget/base/actualbudget.yaml:14-16`

**Error Message**:

```
failed to provision volume with StorageClass "longhorn-default":
rpc error: code = Unknown desc = XFS filesystems with size 209715200,
smaller than 314572800, are not supported
```

**Analysis**:

The PVC requests 200Mi (209,715,200 bytes):

```yaml
resources:
  requests:
    storage: 200Mi
```

Longhorn's XFS filesystem implementation requires a minimum of 300Mi
(314,572,800 bytes). This is a hard limit enforced by the XFS filesystem driver
in Linux.

**Impact**:

- Pod `actualbudget-66d8b86c7-drqnj` stuck in Pending state for 6d5h
- Continuous VolumeBinding failures every ~10 minutes (2,393 provisioning
  attempts)
- Deployment marked as ProgressDeadlineExceeded after 10m timeout

**Verification**:

```
$ kubectl describe pvc actualbudget-pvc -n actualbudget
Warning  ProvisioningFailed  35s (x2393 over 6d5h)  driver.longhorn.io_csi-provisioner
```

### Issue 2: authentik & miniflux - Invalid StorageClass Parameter

**Location**: `k8s/apps/longhorn-config/base/storage-class.yaml:61`

**Error Message**:

```
failed to provision volume with StorageClass "longhorn-cnpg-strict-local":
rpc error: code = InvalidArgument desc = invalid parameter unmapMarkSnapChainRemoved:
invalid UnmapMarkSnapChainRemoved setting: true
```

**Analysis**:

The `longhorn-cnpg-strict-local` StorageClass includes:

```yaml
parameters:
  unmapMarkSnapChainRemoved: "true" # Better space reclamation for DB churn
```

This parameter is not supported in Longhorn v1.11.0 (current cluster version).
Research suggests:

- Parameter may have been deprecated/removed in recent Longhorn versions
- Or it was never a valid parameter and came from outdated documentation
- The feature might be enabled by default in v1.11.0, making the explicit
  parameter invalid

**Longhorn Version**:

```
$ kubectl get deployment -n longhorn longhorn-driver-deployer -o jsonpath='{.spec.template.spec.containers[0].image}'
docker.io/longhornio/longhorn-manager:v1.11.0
```

**Impact on authentik**:

- Database init pod `authentik-cnpg-db-1-initdb-zsrt8` cannot schedule (no
  volume)
- Pooler pods running (2/2) but have no database to connect to
- Server pod in restart loop (894 restarts over 6d5h):
  ```
  PostgreSQL connection failed: FATAL: server login has been failing,
  cached error: connect failed (server_login_retry)
  ```
- Worker pod in CrashLoopBackOff (1,520 restarts over 6d5h) with same DB
  connection error
- 2,393 failed provisioning attempts over 6 days

**Impact on miniflux**:

- Database init pod `miniflux-cnpg-db-1-initdb-l28mw` cannot schedule (no
  volume)
- Pooler pods running (2/2) but have no database to connect to
- App pod in CrashLoopBackOff (1,745 restarts over 6d5h):
  ```
  pq: server login has been failing, cached error: connect failed (server_login_retry)
  ```
- 2,391 failed provisioning attempts over 6 days

**Cascading Effects**:

Both applications have their PostgreSQL databases managed by CloudNative-PG
operator. The provisioning failure creates this dependency chain:

```
PVC Provisioning Failure
    ↓
Database Init Pod Cannot Start (Pending)
    ↓
No PostgreSQL Database Available
    ↓
Pooler Running But Caching Connection Errors
    ↓
Application Pods Crash on DB Connection (CrashLoopBackOff)
    ↓
Deployment Marked Failed
    ↓
HelmRelease Timeout (authentik)
    ↓
Flux Kustomization Health Check Failed
```

## Architecture Overview

### Volume Provisioning Flow

```
Flux Kustomization
    ↓
Creates PVC with StorageClass Reference
    ↓
Kubernetes Scheduler (VolumeBinding plugin)
    ↓
Longhorn CSI Provisioner (driver.longhorn.io)
    ↓
Validates StorageClass Parameters ❌ FAILS HERE (authentik, miniflux)
    OR
Creates XFS Filesystem ❌ FAILS HERE (actualbudget - size too small)
    ↓
Binds PersistentVolume
    ↓
Pod Can Schedule
```

### Affected Resources

**actualbudget**:

- Kustomization: `flux-system/actualbudget` → Failed
- Deployment: `actualbudget/actualbudget` → ProgressDeadlineExceeded
- PVC: `actualbudget/actualbudget-pvc` → Pending
- Pod: `actualbudget/actualbudget-66d8b86c7-drqnj` → Pending
- StorageClass: `longhorn-default`

**authentik**:

- Kustomization: `flux-system/authentik` → Failed
- HelmRelease: `authentik/authentik` → Failed
- Deployments: `authentik/authentik-server` (0/1), `authentik/authentik-worker`
  (0/1) → ProgressDeadlineExceeded
- PVC: `authentik/authentik-cnpg-db-1` → Pending
- Pod: `authentik/authentik-cnpg-db-1-initdb-zsrt8` → Pending
- Pods: `authentik/authentik-server-*` (894 restarts),
  `authentik/authentik-worker-*` (1520 restarts) → CrashLoopBackOff
- StorageClass: `longhorn-cnpg-strict-local`

**miniflux**:

- Kustomization: `flux-system/miniflux` → Unknown (stuck in reconciliation)
- Deployment: `miniflux/miniflux` → 0/1 available
- PVC: `miniflux/miniflux-cnpg-db-1` → Pending
- Pod: `miniflux/miniflux-cnpg-db-1-initdb-l28mw` → Pending
- Pod: `miniflux/miniflux-*` (1745 restarts) → CrashLoopBackOff
- StorageClass: `longhorn-cnpg-strict-local`

## Resolution

### Required Change 1: Increase actualbudget PVC Size

**File**: `k8s/apps/actualbudget/base/actualbudget.yaml`

```diff
 spec:
   storageClassName: longhorn-default
   accessModes:
     - ReadWriteOnce
   resources:
     requests:
-      storage: 200Mi
+      storage: 1Gi  # XFS minimum is ~300Mi; 1Gi provides headroom
```

**Rationale**:

- XFS requires minimum 300Mi
- 1Gi provides reasonable working space for actualbudget data
- Minimal cost increase (800Mi per replica = ~1.6Gi total with 2 replicas)

### Required Change 2: Remove Invalid StorageClass Parameter

**File**: `k8s/apps/longhorn-config/base/storage-class.yaml`

```diff
 parameters:
   numberOfReplicas: "1"
   dataLocality: "strict-local"
   fsType: "xfs"
   dataEngine: "v1"
   staleReplicaTimeout: "30"
-  unmapMarkSnapChainRemoved: "true"
   migratable: "false"
   recurringJobSelector: |
     [
       {"name": "weekly-trim", "isGroup": false}
     ]
```

**Rationale**:

- Parameter not supported in Longhorn v1.11.0
- No documented benefit for the parameter in current version
- Removal unblocks CloudNative-PG database provisioning

### Post-Fix Recovery Steps

After applying both fixes and committing to Git:

1. **Wait for Flux to reconcile** (automatic):

   ```bash
   flux reconcile kustomization longhorn-config
   flux reconcile kustomization actualbudget
   flux reconcile kustomization authentik
   flux reconcile kustomization miniflux
   ```

2. **Delete stuck PVCs** (will be recreated by Flux):

   ```bash
   kubectl delete pvc actualbudget-pvc -n actualbudget
   kubectl delete pvc authentik-cnpg-db-1 -n authentik
   kubectl delete pvc miniflux-cnpg-db-1 -n miniflux
   ```

3. **Verify PVC provisioning succeeds**:

   ```bash
   kubectl get pvc -A | grep -E 'actualbudget|authentik|miniflux'
   # All should show Bound status within ~30s
   ```

4. **Verify pods start successfully**:

   ```bash
   # actualbudget
   kubectl get pods -n actualbudget
   kubectl logs -n actualbudget deployment/actualbudget

   # authentik
   kubectl get pods -n authentik
   kubectl logs -n authentik deployment/authentik-server
   kubectl logs -n authentik deployment/authentik-worker

   # miniflux
   kubectl get pods -n miniflux
   kubectl logs -n miniflux deployment/miniflux
   ```

5. **Verify Flux health checks pass**:
   ```bash
   flux get kustomizations -A
   flux get helmreleases -A
   # All should show Ready=True
   ```

## Additional Considerations

### Resource Waste from Retry Loops

Over 6 days, the three failed provisioning attempts have generated:

- ~2,393 provisioning attempts per PVC × 3 PVCs = ~7,179 total attempts
- Each retry generates API calls, logs, events, and scheduler overhead
- Continuous pod restarts (authentik-worker: 1,520 × log writes + resource
  allocation)

### Why This Wasn't Caught Earlier

1. **actualbudget**: Size requirement (300Mi) is not well-documented in Longhorn
   or XFS documentation. The minimum was likely determined empirically by the
   XFS kernel module.

2. **StorageClass parameter**: The `unmapMarkSnapChainRemoved` parameter may
   have been:
   - Valid in an earlier Longhorn version and deprecated
   - Copied from unofficial documentation or blog posts
   - A misunderstanding of Longhorn's space reclamation features

3. **Testing gap**: These applications were likely deployed to a fresh cluster
   without pre-existing validation of:
   - Minimum volume sizes for XFS
   - StorageClass parameter compatibility with Longhorn v1.11.0

### Related Configuration

The `longhorn-default` StorageClass (used by actualbudget) is correctly
configured:

```yaml
parameters:
  fsType: "xfs"
  numberOfReplicas: "2"
  dataLocality: "best-effort"
  # No invalid parameters
```

The only issue is the consuming PVC's size request.

## Verification Commands

```bash
# Check all PVC provisioning events
kubectl get events -A --field-selector involvedObject.kind=PersistentVolumeClaim --sort-by='.lastTimestamp' | tail -50

# Check Longhorn CSI provisioner logs
kubectl logs -n longhorn deployment/csi-provisioner --tail=100

# Monitor pod scheduling
kubectl get events -A --field-selector reason=FailedScheduling --sort-by='.lastTimestamp' | tail -20

# Verify StorageClass parameters
kubectl get storageclass longhorn-default longhorn-cnpg-strict-local -o yaml

# Check Longhorn system health
kubectl get pods -n longhorn
```

## References

- Longhorn v1.11.0 Documentation: https://longhorn.io/docs/1.11.0/
- XFS Filesystem Minimum Size:
  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-xfs
- CloudNative-PG Operator: https://cloudnative-pg.io/
- Flux CD Health Checks:
  https://fluxcd.io/flux/components/kustomize/kustomizations/#health-assessment
