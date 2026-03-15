# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure as Code (IaC) repository for a personal Kubernetes homelab running on Talos Linux. The stack combines:
- **Talos Linux** (v1.12.4) with Kubernetes v1.35.0 on XCP-ng hypervisor
- **Flux CD v2** for GitOps-based deployment
- **TalHelper** for Talos configuration management
- **Terraform** for infrastructure provisioning (XCP-ng VMs, Authentik, Cloudflare)
- **Ansible** for Docker host management (separate from K8s cluster)

## Common Commands

### Task Runner (Primary Interface)
```bash
task --list                    # List all available tasks

# Bootstrap cluster
task bootstrap:apply_talos     # Apply Talos config to nodes
task bootstrap:bootstrap_talos # Bootstrap Talos cluster
task bootstrap:k8s             # Install Kubernetes components (CRDs, Helm charts)

# Talos operations
task talos:upgrade             # Upgrade Talos version
task talos:upgradek8s          # Upgrade Kubernetes version
task talos:apply               # Apply talos config changes

# Context management
task set_context               # Set BWS, K8s, Talos context (required before kubectl)
task unset_context
```

### Manual Operations
```bash
# Terraform
cd terraform/k8s && terraform plan -var-file=../values.tfvars

# Ansible (Docker host)
ansible-playbook -i ansible/inventory.yml ansible/ares.yml

# Flux status
flux get kustomizations
flux get helmreleases -A

# Talos config generation
talhelper genconfig
```

## Architecture

### Directory Structure
- `k8s/apps/` - Kubernetes application definitions (26 apps)
- `k8s/clusters/dev/` - Flux cluster configuration
- `k8s/components/` - Shared kustomize components (namespace, postgres)
- `k8s/app-flux-kustomizations/` - Flux Kustomization overlays per app
- `talos/dev/` - Talos cluster config (talconfig.yaml, patches/)
- `terraform/` - IaC modules (authentik, xcpng, cloudflare, k8s)
- `ansible/` - Docker host configuration (ares.yml)
- `bootstrap/` - Cluster bootstrap automation (helmfile, CRD templates)
- `taskfiles/` - Modular task definitions

### Application Deployment Pattern
Each app in `k8s/apps/{app}/` follows:
```
base/
  helmrelease.yaml     # Flux HelmRelease
  kustomization.yaml   # Base kustomization
  external-secret.yaml # Optional: Bitwarden secret sync
{cluster}/
  kustomization.yaml   # Cluster overlay
  ocirepository.yaml   # OCI chart source
```

### Secret Management Flow
1. Secrets stored in Bitwarden
2. Terraform bitwarden provider syncs to ExternalSecret resources
3. external-secrets operator creates K8s secrets
4. Reloader annotation triggers pod restarts on secret rotation

### Key Infrastructure Components
- **CNI**: Cilium (installed via Helm, not Talos-managed)
- **Storage**: Longhorn (distributed) + Local Path Provisioner
- **Ingress**: Envoy Gateway
- **Auth**: Authentik (identity provider)
- **Secrets**: Bitwarden Secrets Manager (BWS) + external-secrets
- **Certificates**: cert-manager
- **Database**: CloudNative-PG (PostgreSQL operator)

### Templating Stack
- **Minijinja (.j2)**: Helmfile CRD generation
- **Go Templates (.gotmpl)**: Helmfile values
- **Kustomize**: Final overlays
- **Flux Substitutions**: Cluster-specific values via ConfigMap

## Development Environment

Uses Nix flake (`flake.nix`) with direnv. Required tools are automatically available:
- kubectl, helm, helmfile, kustomize
- talosctl, talhelper
- terraform, ansible
- flux, cilium-cli
- bws (Bitwarden Secrets), minijinja-cli

Run `task set_context` to configure environment variables for kubectl/talosctl access.

## Cluster Details

- **Cluster name**: dk8s
- **Control plane**: 3 nodes (d-hpp-1, d-hpp-2, d-hpp-3) - all schedulable
- **VIP**: 192.168.10.140
- **Nodes use**: Intel hardware with SATA SSDs for Longhorn storage

## Troubleshooting

### Diagnostic Commands
```bash
# Flux status
flux get kustomizations -A
flux get helmreleases -A

# ExternalSecrets status
kubectl get externalsecrets -A
kubectl get clustersecretstores

# Certificate status
kubectl get certificates -n external-secrets
kubectl describe certificate <name> -n external-secrets

# Pod logs
kubectl logs -n external-secrets deployment/external-secrets --tail=100
kubectl logs -n external-secrets deployment/bitwarden-sdk-server --tail=100

# Compare CA certificates (should all match)
kubectl get secret bitwarden-css-certs -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
kubectl get secret bitwarden-tls-certs -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
kubectl get secret bitwarden-ca-keypair -n external-secrets -o jsonpath='{.data.ca\.crt}' | base64 -d | sha256sum
```

### Issue Tracking
Active issues and troubleshooting notes are documented in the `issues/` directory.

### Claude Code Permissions
The `.claude/settings.local.json` is configured for read-only diagnostics:
- **Allowed**: kubectl get/describe/logs, flux get/logs, helm list/status, talosctl read operations
- **Denied**: kubectl apply/delete/edit, helm install/upgrade, flux reconcile, terraform apply
