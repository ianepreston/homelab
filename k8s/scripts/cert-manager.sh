#!/usr/bin/env bash
echo "Installing cert-manager"
CERTMANAGER_REPO_SPEC=$(cat ../apps/cert-manager/base/helmrepository.yaml)
CERTMANAGER_REPO_URL=$(echo "$CERTMANAGER_REPO_SPEC" | yq eval '.spec.url' -)
CERTMANAGER_RELEASE_SPEC=$(kustomize build ../apps/cert-manager/dev | yq 'select(.kind == "HelmRelease")')
CERTMANAGER_VERSION=$(echo "$CERTMANAGER_RELEASE_SPEC" | yq eval '.spec.chart.spec.version')
CERTMANAGER_VALUES=$(echo "$CERTMANAGER_RELEASE_SPEC" | yq eval '.spec.values')
echo "cert-manager repo: $CERTMANAGER_REPO_URL"
echo "cert-manager version: $CERTMANAGER_VERSION"
echo "cert-manager values: $CERTMANAGER_VALUES"
helm repo add jetstack "$CERTMANAGER_REPO_URL" --force-update
echo "$CERTMANAGER_VALUES" |\
  helm install cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --version "$CERTMANAGER_VERSION" \
  jetstack/cert-manager \
  --values -
