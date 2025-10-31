#!/usr/bin/env bash
echo "Installing cilium"
CILIUM_REPO_SPEC=$(cat ../apps/cilium/base/helmrepository.yaml)
CILIUM_REPO_URL=$(echo "$CILIUM_REPO_SPEC" | yq eval '.spec.url' -)
CILIUM_RELEASE_SPEC=$(kustomize build ../apps/cilium/dev | yq 'select(.kind == "HelmRelease")')
CILIUM_VERSION=$(echo "$CILIUM_RELEASE_SPEC" | yq eval '.spec.chart.spec.version')
CILIUM_VALUES=$(echo "$CILIUM_RELEASE_SPEC" | yq eval '.spec.values')
echo "cilium repo: $CILIUM_REPO_URL"
echo "cilium version: $CILIUM_VERSION"
echo "cilium values: $CILIUM_VALUES"
helm repo add cilium "$CILIUM_REPO_URL" --force-update
echo "$CILIUM_VALUES" |\
  helm install cilium \
    cilium/cilium \
    --version "$CILIUM_VERSION" \
    --namespace kube-system \
    --values -
