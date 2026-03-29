# CNPG Backup Strategy

## Context

This document defines the backup strategy for CloudNative-PG databases in the
homelab environment. The cluster runs on Talos Linux with Longhorn storage, with
Garage (S3-compatible) available on the NAS for off-cluster backups.

### Requirements

- **RPO**: 1 day acceptable
- **RTO**: Not critical (homelab)
- **Quick rollback**: Ability to restore a database to a known good state after
  application errors
- **Disaster recovery**: Off-cluster backups to NAS for cluster-loss scenarios
- **Operational simplicity**: Prefer one-time setup complexity over ongoing
  operational overhead

### Current CNPG Deployments

| Cluster           | Namespace | Instances | Storage | Storage Class              |
| ----------------- | --------- | --------- | ------- | -------------------------- |
| authentik-cnpg-db | authentik | 2         | 2Gi     | longhorn-cnpg-strict-local |
| miniflux-cnpg-db  | miniflux  | 2         | 2Gi     | longhorn-cnpg-strict-local |

Both clusters use 2 instances for HA. The `longhorn-cnpg-strict-local` storage
class intentionally uses single-replica Longhorn volumes (`numberOfReplicas: 1`)
to avoid redundant replication—CNPG's database-level HA already provides
instance redundancy, so Longhorn replication would add overhead without
meaningful benefit.

### Current Protection Gap

| Layer                   | Status             | Notes                                    |
| ----------------------- | ------------------ | ---------------------------------------- |
| CNPG HA (2 instances)   | Active             | Protects against single pod/node failure |
| Longhorn replication    | 1 replica          | Intentional—HA at database layer         |
| Longhorn snapshots      | **None**           | Storage class has no snapshot jobs       |
| Longhorn backups to NAS | **None**           | Storage class excludes backup group      |
| CNPG backups            | **Not configured** | No backup destination defined            |

**Risk**: Complete data loss if both CNPG instances fail simultaneously (storage
corruption, accidental deletion, cluster rebuild).

---

## Backup Approach

### Why CNPG Object Store Backups

Given the requirements and existing infrastructure, CNPG's native object store
backups to Garage provide the cleanest solution:

**Single backup per cluster**: CNPG backs up from one instance (the designated
replica), not all instances. This avoids the double-backup overhead that
Longhorn-level backups would create (2 PVCs per cluster containing redundant
data).

**PostgreSQL-aware**: Backups use PostgreSQL's native mechanisms (pg_basebackup
for base backups, WAL archiving for continuous protection), guaranteeing
consistency. This avoids the crash-consistency concerns of block-level snapshots
taken during active writes.

**Continuous WAL archiving with PITR**: WAL segments are archived continuously
to S3, enabling point-in-time recovery to any moment within the retention
window. While the stated RPO is 1 day, PITR provides finer granularity at
minimal additional cost for these small databases.

**Built-in retention**: CNPG supports retention policies directly in the cluster
spec, matching the tiered retention used for Longhorn backups.

**Clean recovery path**: Recovery uses `bootstrap.recovery.source` pointing to
the backup location. Single, well-documented mechanism with no ambiguity about
which volume to restore.

### Alternatives Considered

**Longhorn-level backups**: Would backup both PVCs redundantly, aren't
PostgreSQL-aware, and have more complex recovery paths (which volume? manual
PV/PVC creation, PostgreSQL recovery mode).

**Kubernetes VolumeSnapshots**: Require snapshot controller and
VolumeSnapshotClass setup, have no native off-cluster export (would need
Longhorn backup or Velero), and lack retention policy support per CNPG docs.

---

## Implementation

### Infrastructure

**Garage endpoint**: `s3.laconia.ipreston.net`

**Bucket structure**:

- Dev cluster: `dev-cnpg-backup`
- Prod cluster: `prod-cnpg-backup`

Each CNPG cluster stores backups at `s3://{cluster-bucket}/{app}-cnpg-db/`.

### Retention Policy

Database backups use longer retention than standard Longhorn volumes given the
criticality of database state:

| Backup Type | Schedule      | Retention |
| ----------- | ------------- | --------- |
| Base backup | Daily at 2 AM | 7 days    |
| Base backup | Weekly        | 4 weeks   |
| Base backup | Monthly       | 12 months |
| WAL archive | Continuous    | 7 days    |

### Component Modifications

The postgres kustomize component (`k8s/components/postgres/`) needs the
following additions:

**cluster.yaml** - Add backup configuration:

```yaml
spec:
  # ... existing spec ...
  backup:
    barmanObjectStore:
      destinationPath: "s3://${CNPG_BACKUP_BUCKET}/${APP}-cnpg-db"
      endpointURL: "https://s3.laconia.ipreston.net"
      s3Credentials:
        accessKeyId:
          name: cnpg-backup-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: cnpg-backup-creds
          key: SECRET_ACCESS_KEY
    retentionPolicy: "7d"
```

**scheduled-backup.yaml** - New resource for daily backups:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: ${APP}-cnpg-db-daily
  namespace: ${APP}
spec:
  schedule: "0 2 * * *"
  backupOwnerReference: self
  cluster:
    name: ${APP}-cnpg-db
```

**external-secret.yaml** - Credentials for S3 access:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cnpg-backup-creds
  namespace: ${APP}
spec:
  secretStoreRef:
    name: bitwarden-secrets-manager
    kind: ClusterSecretStore
  target:
    name: cnpg-backup-creds
  data:
    - secretKey: ACCESS_KEY_ID
      remoteRef:
        key: <bitwarden-secret-id>
        property: access_key_id
    - secretKey: SECRET_ACCESS_KEY
      remoteRef:
        key: <bitwarden-secret-id>
        property: secret_access_key
```

**kustomization.yaml** - Include new resources:

```yaml
resources:
  - ./cluster.yaml
  - ./podmonitor.yaml
  - ./pooler.yaml
  - ./scheduled-backup.yaml
  - ./external-secret.yaml
```

### Flux Kustomization Changes

Add the backup bucket variable to each app's Flux Kustomization
(`k8s/app-flux-kustomizations/apps/{cluster}/{app}.yaml`):

```yaml
postBuild:
  substitute:
    APP: *app
    DB_STORAGE: 2Gi
    CNPG_BACKUP_BUCKET: dev-cnpg-backup  # or prod-cnpg-backup
```

Alternatively, add `CNPG_BACKUP_BUCKET` to the `cluster-config` ConfigMap for
cluster-wide substitution.

### Weekly/Monthly Backups

CNPG's `retentionPolicy` handles daily cleanup, but for the 4-week and 12-month
retention tiers, you have a few options:

1. **Multiple ScheduledBackup resources**: Create separate weekly and monthly
   ScheduledBackup resources with different names/schedules, and use S3
   lifecycle rules on the bucket for tiered retention

2. **Garage/S3 lifecycle policies**: Configure object lifecycle rules on the
   bucket to retain certain backups longer based on naming patterns or tags

3. **Accept simpler retention**: Use only daily with 7-day retention; if more
   historical depth is needed later, add complexity then

---

## Recovery Procedures

Recovery scenarios differ based on whether you're recovering a single database
(application error, corruption) or rebuilding after cluster loss.

### Single Database Recovery

When an individual database needs rollback while the cluster is healthy:

1. **Create a recovery cluster manifest** - This is intentionally _not_ part of
   the component, since recovery is a one-time operation with specific
   parameters:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: ${APP}-cnpg-db-restored
  namespace: ${APP}
spec:
  instances: 2
  storage:
    size: ${DB_STORAGE}
    storageClass: longhorn-cnpg-strict-local
  bootstrap:
    recovery:
      source: ${APP}-cnpg-db-backup
      # For point-in-time recovery:
      # recoveryTarget:
      #   targetTime: "2024-03-28T10:00:00Z"
  externalClusters:
    - name: ${APP}-cnpg-db-backup
      barmanObjectStore:
        destinationPath: "s3://${CNPG_BACKUP_BUCKET}/${APP}-cnpg-db"
        endpointURL: "https://s3.laconia.ipreston.net"
        s3Credentials:
          accessKeyId:
            name: cnpg-backup-creds
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-backup-creds
            key: SECRET_ACCESS_KEY
```

2. **Apply the recovery manifest** directly with `kubectl apply` (not via Flux)

3. **Verify the restored data** is correct

4. **Update the application** to point to `${APP}-cnpg-db-restored`

5. **Clean up** the old cluster and optionally rename the restored one

This approach keeps recovery operations explicit and auditable, separate from
the GitOps-managed steady-state configuration.

### Disaster Recovery (Cluster Loss)

When rebuilding the entire cluster:

1. **Bootstrap the cluster** using standard procedures (Talos, Flux, operators)

2. **Deploy the postgres component normally** - It will create empty CNPG
   clusters since `bootstrap.initdb` is the default

3. **For each database requiring restoration**, follow the single database
   recovery procedure above, or modify the component temporarily to use
   `bootstrap.recovery` instead of `bootstrap.initdb`

The key insight is that the component is designed for steady-state operation
(new databases). Recovery is an exceptional operation that warrants explicit,
manual intervention rather than trying to encode recovery logic into the GitOps
workflow.

---

## Outstanding Items

1. **Bitwarden secret setup**: Create a secret in Bitwarden containing Garage
   credentials (`access_key_id`, `secret_access_key`) and note the secret ID for
   the ExternalSecret configuration.

2. **Weekly/monthly retention approach**: Decide between multiple
   ScheduledBackup resources, S3 lifecycle rules, or simpler daily-only
   retention initially.

3. **PG_MAJOR variable source**: The component references `${PG_MAJOR}` -
   confirm this is already in `cluster-config` ConfigMap or needs to be added
   alongside `CNPG_BACKUP_BUCKET`.

4. **Test recovery procedure**: After implementing, perform a test recovery to
   validate the procedure before relying on it.

---

## References

- [CNPG Backup Documentation](https://cloudnative-pg.io/docs/1.28/backup/)
- [CNPG Recovery Documentation](https://cloudnative-pg.io/docs/1.28/recovery/)
- [Barman Cloud Object Store Configuration](https://cloudnative-pg.io/docs/1.28/appendixes/object_stores/)
- Issue 002: Longhorn Backup and Restore Strategy (for comparison)
