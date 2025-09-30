#!/usr/bin/env bash
# echo "Installing external-secrets"
# EXTERNALSECRETS_REPO_SPEC=$(cat ./infrastructure/controllers/base/external-secrets/helmrepository.yaml)
# EXTERNALSECRETS_REPO_URL=$(echo "$EXTERNALSECRETS_REPO_SPEC" | yq eval '.spec.url' -)
# EXTERNALSECRETS_RELEASE_SPEC=$(cat ./infrastructure/controllers/base/external-secrets/helmrelease.yaml)
# EXTERNALSECRETS_VERSION=$(echo "$EXTERNALSECRETS_RELEASE_SPEC" | yq eval '.spec.chart.spec.version')
# EXTERNALSECRETS_VALUES=$(echo "$EXTERNALSECRETS_RELEASE_SPEC" | yq eval '.spec.values')
# echo "external-secrets repo: $EXTERNALSECRETS_REPO_URL"
# echo "external-secrets version: $EXTERNALSECRETS_VERSION"
# echo "external-secrets values: $EXTERNALSECRETS_VALUES"
# helm repo add external-secrets "$EXTERNALSECRETS_REPO_URL" --force-update
# echo "$EXTERNALSECRETS_VALUES" |\
#   helm install external-secrets \
#   --create-namespace \
#   --namespace external-secrets \
#   --version "$EXTERNALSECRETS_VERSION" \
#   external-secrets/external-secrets \
#   --values -
# echo "Setting up bitwarden secrets"
# Create the self signed certs required for communication between the sdk and bitwarden secrets
# kubectl apply -f ./infrastructure/configs/base/bitwarden-self-signed-cert.yaml
# bws run 'kubectl create secret generic bitwarden-access-token --namespace external-secrets --from-literal token="$machinetoken"'
# Grab the organization and project ID from bws
export PROJECT_ID=$(bws project list | jq -r '.[0].id')
export ORGANIZATION_ID=$(bws project list | jq -r '.[0].organizationId')
echo "$PROJECT_ID"
echo "$ORGANIZATION_ID"
# Parse out the argo vault plugin substitution from the yaml so it can be applied
cat ./scripts/external-secret-store.yaml |\
  sed -e "s|<path:bitwardenids#organizationid>|${ORGANIZATION_ID}|g" \
  -e "s|<path:bitwardenids#projectid>|${PROJECT_ID}|g" |\
  kubectl apply -f -
