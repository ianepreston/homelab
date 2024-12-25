#!/bin/env bash
echo "Installing cert-manager"
echo "This has to be done before Bitwarden Secrets or Argo"
## Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io --force-update
# Figure out what version of cert-manager to install
export certManagerVersion=$(cat ../services/certmanager/chart/Chart.yaml | yq eval '.dependencies[0].version')
# Grab the values from the app chart for certmanager and install with helm
cat ../services/certmanager/chart/values.yaml | yq '.["cert-manager"]' | \
  helm install cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --version $certManagerVersion \
  jetstack/cert-manager \
  --values -
# Install the bitwarden self signed tls cert
kubectl apply -f ../services/certmanager/chart/templates/bitwarden-self-signed-cert.yaml
