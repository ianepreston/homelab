#!/bin/env bash
echo "Installing External Secrets"
echo "This has to be done before Argo"
## Add the Helm repository
helm repo add external-secrets https://charts.external-secrets.io --force-update
# helm repo add jetstack https://charts.jetstack.io --force-update
# Figure out what version of external-secrets to install
export externalsecretsVersion=$(cat ../services/externalsecrets/chart/Chart.yaml | yq eval '.dependencies[0].version')
echo $externalsecretsVersion
# Grab the values from the app chart for externalsecrets and install external secrets
cat ../services/externalsecrets/chart/values.yaml | yq '.["external-secrets"]' | \
  helm install external-secrets \
  --create-namespace \
  --namespace external-secrets \
  --version $externalsecretsVersion \
  external-secrets/external-secrets \
  # --dry-run \
  --values -
