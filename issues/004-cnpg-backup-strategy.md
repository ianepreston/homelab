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

## Backup Storage and Sizing

### How CNPG Backups Work

CNPG backups consist of two components:

**Base backups (full snapshots)**: Each scheduled backup creates a complete
tarball of the entire PostgreSQL data directory using `pg_basebackup`. These are
full physical backups—CNPG object store backups do **not** support incremental
or differential copies (only Kubernetes VolumeSnapshots do, depending on the
storage class).

**WAL archiving (incremental changes)**: Between base backups, PostgreSQL
continuously archives Write-Ahead Log segments (16MB each by default). WAL
captures every transaction. Point-in-time recovery works by: restore a base
backup → replay WAL segments forward to the target time.

### Critical: WAL Retention Is Tied to Base Backups

**WAL is retained back to the oldest base backup you want to recover from.**

This is the key insight for choosing backup frequency. With weekly backups and
70-day retention:

- 10 base backups (one per week)
- **70 days of WAL** — not 7 days

Why? To recover to day 65, CNPG needs the week-9 base backup (day 63) plus WAL
from day 63→65. To recover to day 5, it needs the week-1 base backup plus WAL
from day 1→5. All WAL between the oldest retained base backup and now must be
kept.

```
Week 1: Base backup #1 created
        ← WAL accumulates →
Week 2: Base backup #2 created
        ← WAL accumulates →
...
Week 10: Base backup #10 created
         ← WAL accumulates →
Today

Total WAL retained: 70 days worth (back to base backup #1)
```

### Daily vs Weekly Backups: The Trade-off

| Strategy | Base Backups | WAL Retained | Notes |
|----------|--------------|--------------|-------|
| Daily, 70d retention | 70 × DB size | ~1 day between each | More base backups, minimal WAL |
| Weekly, 70d retention | 10 × DB size | ~70 days total | Fewer base backups, more WAL |

**For stable, low-write databases** (like authentik/miniflux in homelab use):
Weekly backups win. WAL generation is minimal—maybe a few hundred MB over 70
days. You get 7× fewer base backups with negligible WAL overhead.

**For high-write databases**: Daily backups might use less total space because
you only keep ~1 day of WAL between each base backup, rather than accumulating
weeks of transaction logs.

### Compression

CNPG supports compression for both base backups and WAL archives. Available
algorithms: gzip, bzip2, lz4, snappy, xz, zstd.

| Algorithm | Compression Ratio | Backup Speed | CPU Impact | Notes |
|-----------|-------------------|--------------|------------|-------|
| lz4 | ~2-3:1 | Very fast | **Very low** | Best for CPU-constrained systems |
| zstd | ~4:1 | Fast | Low-moderate | Good balance, WAL-only in CNPG |
| snappy | ~2.4:1 | Very fast | Very low | Similar to lz4 |
| gzip | ~4:1 | **Slow** | **High** | 10x slower than uncompressed |
| bzip2 | ~6:1 | Slow | High | Maximum compression |

### Compression Performance Considerations

**Where compression runs:**
- Base backups: On the designated replica pod (not primary)
- WAL archiving: On the **primary** pod via `barman-cloud-wal-archive`

**Why this matters for low-power nodes with multiple databases:**

WAL archiving is continuous — every transaction generates WAL that must be
compressed and uploaded. With gzip, compressing a 16MB WAL segment can take
several seconds of CPU time. Multiply by several databases all archiving WAL
simultaneously, and you can create CPU pressure on nodes that are also serving
production traffic.

Base backups run weekly on replicas, so their CPU impact is less critical.

**CNPG benchmark data:**

| Algorithm | Backup Time | Restore Time |
|-----------|-------------|--------------|
| None | 10.9s | 7.5s |
| snappy | 8.1s | 8.3s |
| gzip | **116s** | 3.1s |
| bzip2 | 25.4s | 13.9s |

gzip takes 10x longer than uncompressed for backups. For WAL archiving on busy
databases, this overhead is continuous.

**Recommendation for low-power multi-database nodes:**

```yaml
spec:
  backup:
    barmanObjectStore:
      wal:
        compression: snappy  # Continuous, runs on primary - minimize CPU
      data:
        compression: gzip    # Weekly, runs on replica - compression matters more
```

This optimizes for:
- Minimal CPU impact on primary (snappy for WAL)
- Good compression ratio for storage (gzip for base backups)
- Base backup CPU overhead isolated to replica pods, once per week

### Storage Estimates for Homelab

For the 2Gi authentik/miniflux databases with typical homelab (low-write) usage:

| Configuration | Estimated Storage per DB |
|---------------|--------------------------|
| Daily, 70d, uncompressed | ~140GB (70 × 2GB) |
| Daily, 70d, gzip | ~35-45GB |
| Weekly, 70d, uncompressed | ~20GB (10 × 2GB) + minimal WAL |
| Weekly, 70d, gzip data | ~5-7GB + minimal WAL |

**Recommended for homelab**: Weekly backups with 70-day retention, snappy for
WAL (low CPU) and gzip for base backups (good compression). Expect **~10-15GB
per database** total.

Note: WAL uses snappy (~2.4:1) instead of gzip (~4:1), but for stable databases
WAL volume is minimal so this has negligible impact on total storage. Base
backups dominate storage and still use gzip.

### Checking Backup Sizes

```bash
# List backups with metadata
kubectl exec -it <cnpg-pod> -n <namespace> -- \
  barman-cloud-backup-list \
  --endpoint-url https://s3.laconia.ipreston.net \
  s3://dev-cnpg-bucket/authentik-cnpg-db

# Check S3 bucket size (using MinIO client or aws-cli)
mc du garage/dev-cnpg-bucket/authentik-cnpg-db/

# Check WAL generation rate on the primary
kubectl exec -it <primary-pod> -n <namespace> -- \
  psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
```

### Monitoring WAL Growth

For stable databases, WAL generation should be minimal. If you see unexpectedly
high WAL volume, investigate:

```bash
# Check recent WAL activity
kubectl exec -it <primary-pod> -n <namespace> -- \
  psql -U postgres -c "SELECT pg_current_wal_lsn(), pg_walfile_name(pg_current_wal_lsn());"

# Compare over time to estimate daily WAL generation
```

High WAL generation in a "stable" database might indicate: autovacuum activity,
connection pooler issues causing reconnects, or application behavior you weren't
aware of.

---

## Implementation

### Infrastructure

**Garage endpoint**: `s3.laconia.ipreston.net`

**Bucket structure**:

- Dev cluster: `dev-cnpg-backup`
- Prod cluster: `prod-cnpg-backup`

Each CNPG cluster stores backups at `s3://{cluster-bucket}/{app}-cnpg-db/`.

### Retention Policy

Given the storage analysis above, a simple approach is preferred over complex
tiered retention:

| Backup Type | Schedule         | Retention |
| ----------- | ---------------- | --------- |
| Base backup | Weekly (Sun 2AM) | 70 days   |
| WAL archive | Continuous       | 70 days   |

This provides:
- 10 weekly base backups
- Point-in-time recovery to any moment in the last 70 days
- ~10-15GB storage per database (with gzip compression)
- No complex S3 lifecycle rules or multiple ScheduledBackup resources

For longer historical snapshots, consider periodic manual backups to a separate
archive location rather than complicating the automated retention.

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
      wal:
        compression: snappy  # Low CPU - runs continuously on primary
      data:
        compression: gzip    # Better ratio - runs weekly on replica
    retentionPolicy: "70d"
```

**scheduled-backup.yaml** - New resource for weekly backups:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: ${APP}-cnpg-db-weekly
  namespace: ${APP}
spec:
  schedule: "0 2 * * 0"  # Sunday at 2 AM
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

### Why Weekly Instead of Daily

With the storage analysis complete (see "Backup Storage and Sizing" above), we
chose weekly backups with a longer retention window rather than daily backups
with tiered retention:

- **Simpler**: Single ScheduledBackup, single retentionPolicy, no S3 lifecycle
  rules
- **Sufficient coverage**: 70-day PITR window exceeds the 1-day RPO requirement
- **Storage efficient**: ~10-15GB per database vs ~35-45GB for daily
- **WAL provides granularity**: Despite weekly base backups, WAL archiving
  enables recovery to any point in time

If longer historical snapshots are needed (quarterly, yearly), create manual
on-demand backups and archive them separately rather than complicating the
automated system

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

## Alternative: Tiered Retention with Multiple Schedules

The implementation above uses a single weekly schedule with 70-day retention.
If you later need more complex tiered retention (daily/weekly/monthly with
different retention periods), here's what to know:

### Multiple ScheduledBackup Resources

You can create multiple ScheduledBackup resources targeting the same cluster
without conflicts:

```yaml
---
# Daily backup at 2 AM
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: ${APP}-cnpg-db-daily
spec:
  schedule: "0 2 * * *"
  cluster:
    name: ${APP}-cnpg-db

---
# Weekly backup at 3 AM on Sunday
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: ${APP}-cnpg-db-weekly
spec:
  schedule: "0 3 * * 0"
  cluster:
    name: ${APP}-cnpg-db
```

### Critical Gotcha: retentionPolicy Is Global

**The Cluster's `retentionPolicy` applies to ALL backups regardless of which
ScheduledBackup created them.**

With `retentionPolicy: "7d"`, your weekly backup will be deleted after 7
days—before your next weekly runs. To do tiered retention, you must either:

1. **Use S3 lifecycle rules** to copy/preserve certain backups before CNPG
   deletes them
2. **Set a long global retention** and accept storing all backups that long
3. **Use separate buckets per tier** (complex, not recommended)

The simple weekly + 70-day approach avoids this complexity entirely.

---

## Ad-Hoc Backup and Recovery

For risky operations (schema migrations, data changes, application upgrades),
you have two ad-hoc options that don't require manifest changes.

### Option 1: On-Demand CNPG Backup

Create a one-off `Backup` resource (not `ScheduledBackup`) for an immediate
backup:

```bash
# Create backup before risky operation
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: authentik-cnpg-db-pre-upgrade-$(date +%s)
  namespace: authentik
spec:
  cluster:
    name: authentik-cnpg-db
EOF

# Monitor backup progress
kubectl get backup -n authentik -w

# Wait for completion
kubectl wait --for=jsonpath='{.status.phase}'=completed \
  backup/authentik-cnpg-db-pre-upgrade-TIMESTAMP -n authentik --timeout=300s
```

**Advantages:**
- Full physical backup with WAL consistency
- Compatible with CNPG's native recovery process
- Stored in S3 alongside scheduled backups
- Supports point-in-time recovery to this exact moment

**Recovery:**
If the risky operation fails, follow the Single Database Recovery procedure
above using `recoveryTarget.targetTime` set to just before the operation.

### Option 2: pg_dump for Quick Logical Backups

For faster, application-level backups that don't require S3 infrastructure:

```bash
# Get the primary pod name
NAMESPACE=authentik
POD=$(kubectl get pods -n $NAMESPACE \
  -l cnpg.io/cluster=authentik-cnpg-db,role=primary \
  -o jsonpath='{.items[0].metadata.name}')

# Dump to local file (application database only)
kubectl exec -it $POD -n $NAMESPACE -- \
  pg_dump -U authentik authentik | gzip > authentik_$(date +%Y%m%d_%H%M%S).sql.gz

# Or dump all databases
kubectl exec -it $POD -n $NAMESPACE -- \
  pg_dumpall -c -U postgres | gzip > authentik_full_$(date +%Y%m%d_%H%M%S).sql.gz
```

**Advantages:**
- Fast and simple—single command
- Portable SQL format works across PostgreSQL versions
- Can selectively dump specific tables or schemas
- Output is human-readable and editable
- No S3 credentials or infrastructure needed

**Disadvantages:**
- No WAL integration—captures a single point in time
- Logical backup—slower restore for large databases
- Must manually manage backup files

### Quick Rollback with pg_dump

The full ad-hoc backup/rollback workflow without touching manifests:

```bash
#!/bin/bash
NAMESPACE=miniflux
CLUSTER=miniflux-cnpg-db
DATABASE=miniflux
USER=miniflux

# 1. Get primary pod
POD=$(kubectl get pods -n $NAMESPACE \
  -l cnpg.io/cluster=$CLUSTER,role=primary \
  -o jsonpath='{.items[0].metadata.name}')

# 2. Create pre-operation backup
BACKUP_FILE="${DATABASE}_pre_migration_$(date +%Y%m%d_%H%M%S).sql.gz"
echo "Creating backup: $BACKUP_FILE"
kubectl exec -it $POD -n $NAMESPACE -- \
  pg_dump -U $USER $DATABASE | gzip > $BACKUP_FILE

# 3. Perform your risky operation...
echo "Backup complete. Perform your operation now."
echo "To rollback if needed, run:"
echo ""
echo "  gunzip -c $BACKUP_FILE | kubectl exec -i $POD -n $NAMESPACE -- psql -U $USER $DATABASE"
```

**Rollback command:**

```bash
# Drop and recreate (destructive but clean)
kubectl exec -it $POD -n $NAMESPACE -- psql -U postgres -c "DROP DATABASE $DATABASE;"
kubectl exec -it $POD -n $NAMESPACE -- psql -U postgres -c "CREATE DATABASE $DATABASE OWNER $USER;"
gunzip -c $BACKUP_FILE | kubectl exec -i $POD -n $NAMESPACE -- psql -U $USER $DATABASE

# Or restore in-place (may leave orphaned objects)
gunzip -c $BACKUP_FILE | kubectl exec -i $POD -n $NAMESPACE -- psql -U $USER $DATABASE
```

### When to Use Each Method

| Scenario | Method | Why |
|----------|--------|-----|
| Major app upgrade | CNPG Backup | Full physical backup, PITR capability |
| Quick schema tweak | pg_dump | Fast, simple, local file |
| Data migration script | pg_dump | Easy rollback, no S3 needed |
| Before cluster maintenance | CNPG Backup | Full consistency with WAL |
| Testing a restore procedure | pg_dump | Non-destructive, can test repeatedly |

### Important: Replication Lag Consideration

Both CNPG clusters (authentik, miniflux) run 2 instances. When using pg_dump,
always target the **primary** pod to ensure you capture committed transactions:

```bash
# Good: Target primary explicitly
-l cnpg.io/cluster=authentik-cnpg-db,role=primary

# Risky: Random pod selection might hit replica with lag
-l cnpg.io/cluster=authentik-cnpg-db
```

---

## Outstanding Items

1. **Bitwarden secret setup**: Create a secret in Bitwarden containing Garage
   credentials (`access_key_id`, `secret_access_key`) and note the secret ID for
   the ExternalSecret configuration.

2. **PG_MAJOR variable source**: The component references `${PG_MAJOR}` -
   confirm this is already in `cluster-config` ConfigMap or needs to be added
   alongside `CNPG_BACKUP_BUCKET`.

3. **Test recovery procedure**: After implementing, perform a test recovery to
   validate the procedure before relying on it.

4. **Monitor initial backup sizes**: After the first few weekly backups, verify
   actual storage usage matches estimates (~10-15GB per database).

5. **Monitor CPU impact**: With multiple databases on low-power nodes, watch for
   CPU spikes during WAL archiving. If snappy still causes issues, consider
   disabling WAL compression entirely (base backups provide disaster recovery,
   PITR granularity is less critical for homelab).

---

## References

- [CNPG Backup Documentation](https://cloudnative-pg.io/docs/1.28/backup/)
- [CNPG Recovery Documentation](https://cloudnative-pg.io/docs/1.28/recovery/)
- [Barman Cloud Object Store Configuration](https://cloudnative-pg.io/docs/1.28/appendixes/object_stores/)
- Issue 002: Longhorn Backup and Restore Strategy (for comparison)
