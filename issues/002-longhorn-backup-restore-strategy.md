# Issue 002: Longhorn Backup and Restore Strategy

**Date**: 2026-03-15
**Status**: Open
**Severity**: Medium - operational risk during disaster recovery

## Summary

While the Longhorn backup infrastructure is well-configured with multi-tier retention
policies to NAS, there are gaps in restore testability and volume identification that
would make disaster recovery challenging. The primary issue is that Longhorn volumes
use internal UUIDs that don't correlate to PVC names, making it difficult to identify
which backup belongs to which application.

## Current State

### What's Working Well

1. **Backup Target**: Correctly configured to NFS on Synology NAS
   ```
   nfs://laconia.ipreston.net:/volume1/k8s-dev-backups/longhorn
   ```

2. **Retention Policy**: Well-structured tiered approach
   | Job | Schedule | Retention | Purpose |
   |-----|----------|-----------|---------|
   | backup-daily | 2 AM | 7 days | Quick recovery |
   | backup-weekly | 4 AM Sunday | 4 weeks | Medium-term |
   | backup-monthly | 6 AM 1st | 12 months | Long-term archive |
   | snap-hourly | :15 each hour | 24 hours | Point-in-time recovery |

3. **StorageClass Configuration**: `reclaimPolicy: Retain` prevents accidental deletion

4. **PVC Naming**: Apps use predictable names (`actualbudget-pvc`, `grafana-pvc`)

### The Problems

#### Problem 1: Volume UUID vs PVC Name Mismatch

Longhorn generates internal volume names as UUIDs (e.g., `pvc-a1b2c3d4-e5f6-...`).
When viewing backups in the Longhorn UI or on the NAS, you see these UUIDs, not
the friendly PVC names like `actualbudget-pvc`.

```
NAS backup directory structure:
/volume1/k8s-dev-backups/longhorn/
├── backupstore/
│   └── volumes/
│       ├── pvc-a1b2c3d4-e5f6-7890-abcd-ef1234567890/
│       │   └── backups/
│       │       ├── backup-abc123.cfg
│       │       └── backup-def456.cfg
│       └── pvc-98765432-1abc-def0-9876-543210fedcba/
│           └── backups/
│               └── ...
```

**DR Scenario**: Cluster is wiped. You need to restore actualbudget data. Which
UUID corresponds to actualbudget? Without the running cluster's PVC metadata,
there's no mapping.

#### Problem 2: No Restore Testing Procedure

The backup system runs automatically but has never been tested for restore. Key
unknowns:

1. How long does a restore take?
2. What's the correct procedure for restoring to a fresh cluster?
3. Are the NFS backups actually usable?
4. What permissions/credentials are needed to access backups?

#### Problem 3: Missing StorageClass

`actualbudget` references `storageClassName: longhorn` but this StorageClass
doesn't exist. The defined classes are:
- `longhorn-default` (default)
- `longhorn-nosnaps`
- `longhorn-cnpg-strict-local`

This likely works because Kubernetes falls back to the default StorageClass, but
it means actualbudget isn't getting the `longhorn-default` recurring jobs attached
properly. The volume may not be getting backed up.

#### Problem 4: StatefulSet PVC Naming

For StatefulSets (Prometheus, Alertmanager), PVC names follow the pattern:
`<volumeClaimTemplate.name>-<statefulset-name>-<ordinal>`

Example: `prometheus-db-prometheus-kube-prometheus-stack-prometheus-0`

This is predictable, but:
- Still maps to a Longhorn UUID internally
- Long names are truncated in some UIs
- Ordinal-based naming complicates restore ordering

## Recommended Changes

### Change 1: Add Longhorn Volume Labels

Configure Longhorn to preserve Kubernetes labels on volumes. This allows you to
identify volumes by app name in the Longhorn UI and backup metadata.

**File**: `k8s/apps/longhorn/base/helmrelease.yaml`

Add to `defaultSettings`:
```yaml
defaultSettings:
  storageMinimalAvailablePercentage: "10"
  # Add these:
  kubernetesClusterAutoscalerEnabled: false
  systemManagedPodsImagePullPolicy: IfNotPresent
```

More importantly, add labels to PVCs at the app level:

**Example for `k8s/apps/actualbudget/base/actualbudget.yaml`**:
```yaml
kind: PersistentVolumeClaim
metadata:
  name: actualbudget-pvc
  labels:
    app.kubernetes.io/name: actualbudget
    app.kubernetes.io/component: data
    backup.longhorn.io/volume-name: actualbudget-data  # Custom label for identification
```

These labels are propagated to the Longhorn volume and appear in backup metadata,
making identification possible during DR.

### Change 2: Fix actualbudget StorageClass Reference

**File**: `k8s/apps/actualbudget/base/actualbudget.yaml`

```diff
 kind: PersistentVolumeClaim
 metadata:
   name: actualbudget-pvc
 spec:
-  storageClassName: longhorn
+  storageClassName: longhorn-default
```

This ensures the backup recurring jobs are attached to the volume.

### Change 3: Create Volume-to-App Mapping Document

Create a reference document that maps PVC names to their purposes. This serves as
a DR runbook reference.

**File**: `docs/longhorn-volume-inventory.md` (or similar)

| PVC Name | Namespace | App | Data Type | Priority | Notes |
|----------|-----------|-----|-----------|----------|-------|
| actualbudget-pvc | actualbudget | Actual Budget | User financial data | High | Critical user data |
| grafana-pvc | monitoring | Grafana | Dashboards, preferences | Medium | Can recreate from GitOps |
| prometheus-db-* | monitoring | Prometheus | Metrics history | Low | Historical only |
| alertmanager-db-* | monitoring | Alertmanager | Silences, state | Low | Can recreate |

During cluster operation, periodically update this with:
```bash
kubectl get pvc -A -o custom-columns=\
'NAMESPACE:.metadata.namespace,NAME:.metadata.name,VOLUME:.spec.volumeName,SIZE:.spec.resources.requests.storage'
```

This gives you the PVC-to-Longhorn-volume mapping that you can store alongside
your GitOps repo.

### Change 4: Implement Backup Verification Job

Create a Kubernetes CronJob that periodically verifies backup integrity.

**Purpose**: Catches backup failures early, before you need them.

**File**: `k8s/apps/longhorn-config/base/backup-verify.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: longhorn-backup-verify
spec:
  schedule: "0 8 * * 1"  # 8 AM Monday
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: verify
              image: alpine:latest
              command:
                - /bin/sh
                - -c
                - |
                  # Mount NFS backup location
                  # List backups and verify metadata files exist
                  # Check backup timestamps are recent
                  # Alert if issues found
          restartPolicy: OnFailure
```

The actual implementation would use Longhorn's API or CLI to enumerate backups
and verify their state.

## Restore Testing Procedure

### Pre-requisites

1. Access to NAS at `laconia.ipreston.net`
2. Longhorn UI accessible at `longhorn.dk8s.ipreston.net`
3. `kubectl` configured for the cluster

### Test 1: Single Volume Restore (Non-Destructive)

This test restores a backup to a NEW volume, without affecting the running app.

1. **Identify the volume to test**
   ```bash
   kubectl get pvc actualbudget-pvc -n actualbudget -o jsonpath='{.spec.volumeName}'
   # Returns: pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

2. **Find the backup in Longhorn UI**
   - Navigate to Backup > find volume by name from step 1
   - Note the most recent backup name

3. **Create a restore PVC**
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: actualbudget-pvc-restore-test
     namespace: actualbudget
   spec:
     storageClassName: longhorn-default
     dataSource:
       name: <backup-name-from-step-2>
       kind: Backup
       apiGroup: longhorn.io
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 200Mi  # Match original size
   ```

4. **Verify the restored data**
   ```bash
   # Create a temporary pod to mount and inspect
   kubectl run restore-verify --rm -it --image=alpine \
     --overrides='{"spec":{"containers":[{"name":"verify","image":"alpine",
     "command":["sh"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],
     "volumes":[{"name":"data","persistentVolumeClaim":
     {"claimName":"actualbudget-pvc-restore-test"}}]}}' \
     -n actualbudget

   # Inside the pod:
   ls -la /data
   # Verify expected files exist
   ```

5. **Cleanup**
   ```bash
   kubectl delete pvc actualbudget-pvc-restore-test -n actualbudget
   ```

### Test 2: Full Disaster Recovery Simulation

This is a more comprehensive test simulating complete cluster loss.

1. **Document current state**
   ```bash
   # Export PVC to volume mappings
   kubectl get pvc -A -o json > pvc-inventory-$(date +%Y%m%d).json

   # Export volume details from Longhorn
   kubectl get volumes.longhorn.io -n longhorn -o json > longhorn-volumes-$(date +%Y%m%d).json
   ```

2. **Verify NAS accessibility**
   ```bash
   # From a machine that can reach the NAS
   ls -la /mnt/laconia/k8s-dev-backups/longhorn/backupstore/volumes/
   # Should see UUID-named directories
   ```

3. **After cluster wipe and rebuild**

   a. Deploy Longhorn with the same backup target configuration

   b. Wait for Longhorn to discover existing backups
      ```bash
      kubectl get backupvolumes.longhorn.io -n longhorn
      # Should list all previously backed-up volumes
      ```

   c. For each critical app, restore using the backup UI or API:
      - Longhorn UI > Backup > Select volume > Create DR Volume
      - Or use `kubectl apply` with dataSource pointing to backup

4. **Restore priority order**
   1. actualbudget (critical user data)
   2. grafana (if dashboards aren't in GitOps)
   3. prometheus/alertmanager (optional - historical metrics)

### Test 3: Backup Freshness Verification

Run monthly to ensure backups are actually happening:

```bash
# Check last backup time for each volume
kubectl get backups.longhorn.io -n longhorn \
  -o custom-columns='VOLUME:.status.volumeName,CREATED:.status.backupCreatedAt'

# Verify no volume has backups older than expected retention
# Daily backups should have one from within last 24 hours
```

## Implementation Priority

1. **Immediate** (before cluster wipe):
   - Export current PVC-to-volume mapping
   - Verify NAS backup target is accessible and contains data
   - Fix actualbudget StorageClass reference

2. **During rebuild**:
   - Add labels to PVCs for better identification
   - Document the restore procedure while it's fresh

3. **Post-rebuild**:
   - Run Test 1 (single volume restore)
   - Set up backup verification CronJob
   - Schedule quarterly DR drill (Test 2)

## Related Issues

- Issue 001: External-Secrets CA Certificate Mismatch (resolved before rebuild)

## References

- [Longhorn Backup and Restore](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/)
- [Longhorn Disaster Recovery](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/restore-statefulset/)
- [Restoring from Backup to New Cluster](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/restore-from-a-backup/)
