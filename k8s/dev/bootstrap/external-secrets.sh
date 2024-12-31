#!/bin/env bash
echo "Installing External Secrets"
## Add the Helm repository
# helm repo add external-secrets https://charts.external-secrets.io --force-update
# Figure out what version of external-secrets to install
# export externalsecretsVersion=$(cat ../services/externalsecrets/chart/Chart.yaml | yq eval '.dependencies[0].version')
# Grab the values from the app chart for externalsecrets and install external secrets
# cat ../services/externalsecrets/chart/values.yaml | yq '.["external-secrets"]' | \
#   helm install external-secrets \
#   --create-namespace \
#   --namespace external-secrets \
#   --version $externalsecretsVersion \
#   external-secrets/external-secrets \
#   --values -
echo "Setting up bitwarden secrets"
# Create the self signed certs required for communication between the sdk and bitwarden secrets
# kubectl apply -f ../services/externalsecrets/chart/templates/bitwarden-self-signed-cert.yaml
# # Create the secret for the access token for bitwarden secrets required for the SecretStore
# bws run 'kubectl create secret generic bitwarden-access-token --namespace bitwarden-secrets --from-literal token="$machinetoken"'
# Grab the organization and project ID from bws
export PROJECT_ID=$(bws project list | jq -r '.[0].id')
export ORGANIZATION_ID=$(bws project list | jq -r '.[0].organizationId')
echo $PROJECT_ID
echo $ORGANIZATION_ID
# Add them to bws so I can use them in external secrets - real bootstrappy/recursive I know
bws secret create projectid $PROJECT_ID $PROJECT_ID
bws secret create organizationid $ORGANIZATION_ID $PROJECT_ID
# Parse out the argo vault plugin substitution from the yaml so it can be applied
cat external-secret-store.yaml |\
  sed -e "s|<path:bitwardenids#organizationid>|${ORGANIZATION_ID}|g" \
  -e "s|<path:bitwardenids#projectid>|${PROJECT_ID}|g" |\
  kubectl apply -f -
