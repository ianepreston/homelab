# Issue 002: Longhorn Backup and Restore Strategy

**Date**: 2026-03-15 **Status**: Open **Severity**: Medium - operational risk
during disaster recovery

## Summary

While the Longhorn backup infrastructure is well-configured with multi-tier
retention policies to NAS, there are gaps in restore testability and volume
identification that would make disaster recovery challenging. The primary issue
is that Longhorn volumes use internal UUIDs that don't correlate to PVC names,
making it difficult to identify which backup belongs to which application.

## Current State

### What's Working Well

1. **Backup Target**: Correctly configured to NFS on Synology NAS

   ```
   nfs://laconia.ipreston.net:/volume1/k8s-dev-backups/longhorn
   ```

2. **Retention Policy**: Well-structured tiered approach

   | Job            | Schedule      | Retention | Purpose                |
   | -------------- | ------------- | --------- | ---------------------- |
   | backup-daily   | 2 AM          | 7 days    | Quick recovery         |
   | backup-weekly  | 4 AM Sunday   | 4 weeks   | Medium-term            |
   | backup-monthly | 6 AM 1st      | 12 months | Long-term archive      |
   | snap-hourly    | :15 each hour | 24 hours  | Point-in-time recovery |

3. **StorageClass Configuration**: `reclaimPolicy: Retain` prevents accidental
   deletion

4. **PVC Naming**: Apps use predictable names (`actualbudget-pvc`,
   `grafana-pvc`)

### The Problems

#### Problem 1: Volume UUID vs PVC Name Mismatch

Longhorn generates internal volume names as UUIDs (e.g.,
`pvc-a1b2c3d4-e5f6-...`). When viewing backups in the Longhorn UI or on the NAS,
you see these UUIDs, not the friendly PVC names like `actualbudget-pvc`.

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

#### Problem 3: StatefulSet PVC Naming

For StatefulSets (Prometheus, Alertmanager), PVC names follow the pattern:
`<volumeClaimTemplate.name>-<statefulset-name>-<ordinal>`

Example: `prometheus-db-prometheus-kube-prometheus-stack-prometheus-0`

This is predictable, but:

- Still maps to a Longhorn UUID internally
- Long names are truncated in some UIs
- Ordinal-based naming complicates restore ordering

## Recommended Changes

### Change 1: Add Labels to PVCs for Volume Identification

Longhorn propagates Kubernetes labels from PVCs to volumes, and these labels
appear in backup metadata. Adding identifying labels to PVCs enables you to
determine which backup belongs to which application during DR.

#### For Directly-Managed PVCs

Add labels to PVCs you define directly in your manifests.

**Example for `k8s/apps/actualbudget/base/actualbudget.yaml`**:

```yaml
kind: PersistentVolumeClaim
metadata:
  name: actualbudget-pvc
  labels:
    app.kubernetes.io/name: actualbudget
    app.kubernetes.io/component: data
    backup.longhorn.io/volume-name: actualbudget-data
```

#### For StatefulSet PVCs (Prometheus, Alertmanager, etc.)

For volumes created by StatefulSets, you cannot label the PVC directly since
Kubernetes creates them from the `volumeClaimTemplate`. Instead, add labels to
the template in the Helm values.

**Example for kube-prometheus-stack** in `helmrelease.yaml`:

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        metadata:
          labels:
            app.kubernetes.io/name: prometheus
            app.kubernetes.io/component: tsdb
            backup.longhorn.io/volume-name: prometheus-metrics
        spec:
          storageClassName: longhorn-default
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        metadata:
          labels:
            app.kubernetes.io/name: alertmanager
            app.kubernetes.io/component: state
            backup.longhorn.io/volume-name: alertmanager-state
```

**Note**: Existing PVCs won't pick up new labels automatically. For StatefulSet
PVCs, you would need to delete and recreate the PVC (losing data), or manually
patch the PVC labels with
`kubectl label pvc <name> -n <ns> backup.longhorn.io/volume-name=<value>`.

### Change 2: Automated PVC-to-Volume Mapping Export

While labels help identify volumes in the Longhorn UI, an automated export of
the PVC-to-volume mapping provides a reliable DR reference without depending on
manual processes.

**Key points about PVC-to-volume mappings:**

- The `spec.volumeName` (the Longhorn UUID) is stable once a PVC is bound
- It only changes if you delete and recreate the PVC
- An automated export ensures you always have a current mapping without
  remembering to run it

**File**: `k8s/apps/longhorn-config/base/pvc-inventory-export.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pvc-inventory-export
  namespace: longhorn
spec:
  schedule: "0 3 * * *" # 3 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: pvc-inventory-exporter
          containers:
            - name: export
              image: bitnami/kubectl:latest
              command:
                - /bin/sh
                - -c
                - |
                  DATE=$(date +%Y%m%d)

                  # Export PVC mappings as JSON
                  kubectl get pvc -A -o json > /export/pvc-inventory-${DATE}.json

                  # Export human-readable summary
                  kubectl get pvc -A -o custom-columns=\
                  'NAMESPACE:.metadata.namespace,NAME:.metadata.name,VOLUME:.spec.volumeName,LABELS:.metadata.labels' \
                  > /export/pvc-inventory-${DATE}.txt

                  # Keep last 30 days of exports
                  find /export -name "pvc-inventory-*" -mtime +30 -delete
              volumeMounts:
                - name: export-volume
                  mountPath: /export
          volumes:
            - name: export-volume
              nfs:
                server: laconia.ipreston.net
                path: /volume1/k8s-dev-backups/pvc-inventory
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pvc-inventory-exporter
  namespace: longhorn
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pvc-reader
rules:
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pvc-inventory-exporter
subjects:
  - kind: ServiceAccount
    name: pvc-inventory-exporter
    namespace: longhorn
roleRef:
  kind: ClusterRole
  name: pvc-reader
  apiGroup: rbac.authorization.k8s.io
```

This complements the labeling strategy: labels help you identify volumes in the
Longhorn UI during normal operations, while the automated export gives you a
reliable mapping file for DR scenarios when the cluster is gone.

### Change 3: Implement Backup Verification Job

Create a Kubernetes CronJob that periodically verifies backup integrity.

**Purpose**: Catches backup failures early, before you need them.

**File**: `k8s/apps/longhorn-config/base/backup-verify.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: longhorn-backup-verify
spec:
  schedule: "0 8 * * 1" # 8 AM Monday
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

## Restore Procedures

### Understanding Longhorn Restore Workflow

When you rebuild a cluster and redeploy your GitOps manifests:

1. **Flux deploys your app manifests** including PVC definitions
2. **Kubernetes creates new PVCs** which Longhorn provisions as new, empty
   volumes
3. **New UUIDs are generated** - these are different from your backed-up volumes

The backed-up data still exists on the NAS, but it's associated with the _old_
volume UUIDs. To restore, you must either:

- **Option A**: Restore before deploying apps - create volumes from backup
  first, then deploy apps pointing to those volumes
- **Option B**: Restore after deployment - delete the empty PVC, restore from
  backup to the same PVC name

**There is no automatic restoration**. Longhorn will discover old backups when
you configure the same backup target, but it won't automatically associate them
with new PVCs.

### Pre-requisites

1. Access to NAS at `laconia.ipreston.net`
2. Longhorn UI accessible at `longhorn.dk8s.ipreston.net`
3. `kubectl` configured for the cluster
4. PVC inventory export from `/volume1/k8s-dev-backups/pvc-inventory/`

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
         storage: 200Mi # Match original size
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

This simulates complete cluster loss and restoration.

#### Phase 1: Before Cluster Wipe (or from existing exports)

```bash
# If cluster is still running, export current state
kubectl get pvc -A -o json > pvc-inventory-$(date +%Y%m%d).json
kubectl get volumes.longhorn.io -n longhorn -o json > longhorn-volumes-$(date +%Y%m%d).json

# Or retrieve from automated exports on NAS
ls /mnt/laconia/k8s-dev-backups/pvc-inventory/
```

#### Phase 2: After Cluster Rebuild

1. **Deploy Longhorn first** with the same backup target configuration

2. **Wait for backup discovery**

   ```bash
   kubectl get backupvolumes.longhorn.io -n longhorn
   # Should list all previously backed-up volumes by their old UUIDs
   ```

3. **Identify which backup corresponds to which app** using:
   - The PVC inventory export (maps PVC names to UUIDs)
   - Volume labels visible in Longhorn UI (if you added them)

4. **For each critical app, restore BEFORE deploying the app**:

   a. In Longhorn UI: Backup > Select the correct volume UUID > Create Volume
   - Name the new volume something identifiable (e.g., `actualbudget-restored`)

   b. Create a PV and PVC pointing to the restored volume:

   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: actualbudget-pv
   spec:
     capacity:
       storage: 200Mi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: longhorn-default
     csi:
       driver: driver.longhorn.io
       volumeHandle: actualbudget-restored # The volume name from step a
       fsType: ext4
   ---
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: actualbudget-pvc
     namespace: actualbudget
   spec:
     storageClassName: longhorn-default
     volumeName: actualbudget-pv # Bind to specific PV
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 200Mi
   ```

   c. Then deploy the app - it will use the pre-existing PVC with restored data

5. **Alternative: Restore after app deployment**

   If the app was already deployed with an empty volume:

   ```bash
   # Scale down the app
   kubectl scale deployment actualbudget -n actualbudget --replicas=0

   # Delete the empty PVC (data loss of empty volume is fine)
   kubectl delete pvc actualbudget-pvc -n actualbudget

   # Create PV/PVC pointing to restored backup (as above)
   kubectl apply -f restored-pvc.yaml

   # Scale app back up
   kubectl scale deployment actualbudget -n actualbudget --replicas=1
   ```

#### Restore Priority Order

1. **actualbudget** - Critical user data
2. **grafana** - Only if dashboards aren't in GitOps
3. **prometheus/alertmanager** - Optional, historical metrics only

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

1. **Immediate** (before any cluster changes):
   - Verify NAS backup target is accessible and contains data
   - Run PVC inventory export manually and save to NAS

2. **Short-term**:
   - Add labels to PVCs (direct and StatefulSet templates)
   - Deploy automated PVC inventory export CronJob
   - Run Test 1 (single volume restore) to validate procedure

3. **Ongoing**:
   - Set up backup verification CronJob
   - Schedule quarterly DR drill (Test 2)

## Related Issues

- Issue 001: External-Secrets CA Certificate Mismatch (resolved before rebuild)

## References

- [Longhorn Backup and Restore](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/)
- [Longhorn Disaster Recovery](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/restore-statefulset/)
- [Restoring from Backup to New Cluster](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/restore-from-a-backup/)
