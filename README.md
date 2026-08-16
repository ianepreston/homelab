# homelab

Infrastructure as code for a personal Kubernetes homelab. The cluster (`dk8s`) runs
[Talos Linux](https://www.talos.dev/) on bare metal and is managed with GitOps via Flux.

This repo covers the Kubernetes cluster and its supporting infrastructure only.

## Cluster

| | |
|---|---|
| Nodes | `d-hpp-1`, `d-hpp-2`, `d-hpp-3` — 3 control plane, all schedulable |
| Endpoint | `https://192.168.10.140:6443` (VIP) |
| Talos | v1.12.4 |
| Kubernetes | v1.35.0 |

Storage is split across two disks per node: the NVMe system disk, and a SATA SSD carved
into `longhorn` and `localpath` user volumes.

## Platform

| Concern | Component |
|---|---|
| CNI | Cilium (installed at bootstrap, not Talos-managed) |
| Ingress | Envoy Gateway |
| Storage | Longhorn (replicated) + local-path (node-local) |
| Certificates | cert-manager (Let's Encrypt via Cloudflare DNS-01) |
| Secrets | Bitwarden Secrets Manager → external-secrets |
| Database | CloudNativePG |
| Identity | Authentik |
| Monitoring | kube-prometheus-stack + Grafana Operator |
| Registry cache | Spegel |

## Layout

```
k8s/apps/                      # one directory per app: base/ + dev/ overlay
k8s/app-flux-kustomizations/   # Flux Kustomizations, split platform/ and apps/
k8s/clusters/dev/              # Flux entrypoints (platform.yaml, apps.yaml)
k8s/components/                # shared kustomize components (namespace, postgres)
talos/dev/                     # talconfig.yaml + machine config patches
terraform/                     # authentik/ and k8s/ (Cloudflare, Bitwarden)
bootstrap/                     # helmfile + CRD templates for initial install
taskfiles/                     # task definitions, included by ./Taskfile.yaml
scripts/garage/                # Garage S3 (backup target) config for the NAS
```

Infrastructure components live under `platform/` and reconcile before `apps/`. Operators
and their custom resources are separate apps — `cert-manager` and `cert-manager-config`,
`longhorn` and `longhorn-config` — so CRDs are established before CRs are applied.

## Working with the repo

The Nix flake provides every tool (`kubectl`, `helm`, `helmfile`, `talosctl`, `talhelper`,
`flux`, `terraform`, `bws`, …). With direnv, `cd` into the repo and it loads.

```bash
task set_context     # write kubeconfig/talosconfig/BWS vars to k8s.env — do this first
task --list          # everything available
```

### Day-to-day

```bash
flux get kustomizations -A
flux get helmreleases -A
task talos:apply             # apply talos machine config changes
task talos:upgrade           # upgrade Talos
task talos:upgradek8s        # upgrade Kubernetes
```

### Bootstrapping from scratch

```bash
talhelper genconfig                # render machine configs from talconfig.yaml
task bootstrap:apply_talos         # push config to nodes in maintenance mode
task bootstrap:bootstrap_talos     # bootstrap etcd, fetch kubeconfig
task bootstrap:k8s                 # namespaces, CRDs, and platform charts via helmfile
```

After `bootstrap:k8s`, Flux takes over and reconciles the rest from this repo.

## Secrets

Secrets live in Bitwarden Secrets Manager. Terraform provisions the `ExternalSecret`
resources, external-secrets syncs them into the cluster, and Reloader restarts the
affected pods when a secret rotates. Nothing sensitive is committed here.

## Notes

- Issues and troubleshooting write-ups are tracked as GitHub issues.
- `scripts/performancetest/` — storage benchmark manifests (Longhorn vs local-path vs NAS).
