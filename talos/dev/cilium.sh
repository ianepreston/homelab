#!/usr/bin/env bash
echo "Installing cilium"
CILIUM_CHART=$(cat ../../k8s/dev/services/cilium/chart/Chart.yaml)
CILIUM_REPO=$(echo "$CILIUM_CHART" | yq eval '.dependencies[0].repository' -)
CILIUM_VERSION=$(echo "$CILIUM_CHART" | yq eval '.dependencies[0].version')
echo "cilium repo: $CILIUM_REPO"
echo "cilium version: $CILIUM_VERSION"
helm repo add cilium $CILIUM_REPO
cat ../../k8s/dev/services/cilium/chart/values.yaml | yq '.["cilium"]' |\
  helm install cilium \
    cilium/cilium \
    --version $CILIUM_VERSION \
    --namespace kube-system \
    --values -
