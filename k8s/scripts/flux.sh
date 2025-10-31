#!/usr/bin/env bash
echo "Installing flux"
# Create a secure temporary file
KEY_FILE=$(mktemp)

# Ensure cleanup on exit
cleanup() {
    rm -f "$KEY_FILE"
}
trap cleanup EXIT

helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace

bws run -- "echo \"\$GITHUB_APP_KEY\" > $KEY_FILE"


bws run -- "flux create secret githubapp flux-system \
  --app-id=\"\$GITHUB_APP_ID\" \
  --app-installation-id=\"\$GITHUB_INSTALLATION_ID\" \
  --app-private-key=\"$KEY_FILE\""

kubectl apply -f ./flux-dev-instance.yaml

