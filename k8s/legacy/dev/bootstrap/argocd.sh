#!/bin/env bash
echo "Installing argo-cd"
ARGO_CHART=$(cat ../services/argocd/chart/Chart.yaml)
HELM_REPO=$(echo "$ARGO_CHART" | yq eval '.dependencies[0].repository' -)
ARGO_VERSION=$(echo "$ARGO_CHART" | yq eval '.dependencies[0].version')
ARGO_VALS=$(cat ../services/argocd/chart/values.yaml | yq '.["argo-cd"]' - | yq eval 'del(.configs.cm)' -)
ARGO_NAMESPACE=$(cat ../services/argocd/chart/templates/namespace.yaml | yq eval '.metadata.name')
echo "helm repo: $HELM_REPO"
echo "argo version: $ARGO_VERSION"
echo "argo namespace: $ARGO_NAMESPACE"
kubectl apply -f ../services/argocd/chart/templates/namespace.yaml
# # Add the project and organization IDs so they're available for templating
kubectl apply -f ../services/argocd/chart/templates/external-secrets.yaml
# Get the github info so it can be interpolated into the bootstrap script
GITHUB_INSTALLATION_ID=$(bws secret list | yq '.[] | select(.key == "argocd-github-installation-id") | .value')
echo $GITHUB_INSTALLATION_ID
GITHUB_APP_ID=$(bws secret list | yq '.[] | select(.key == "argocd-github-app-id") | .value')
echo $GITHUB_APP_ID
GITHUB_APP_KEY=$(bws secret list | yq '.[] | select(.key == "argocd-github-app-key") | .value')
echo $GITHUB_APP_KEY
# Install the repo resource with string interpolation
awk -v INSTALLATION_ID="$GITHUB_INSTALLATION_ID" \
    -v APP_KEY="$GITHUB_APP_KEY" \
    -v APP_ID="$GITHUB_APP_ID" '
{
    if ($0 ~ /<path:githubkey#argocd-github-installation-id>/) {
        gsub("<path:githubkey#argocd-github-installation-id>", INSTALLATION_ID)
    }
    if ($0 ~ /<path:githubkey#argocd-github-app-key>/) {
        sub("<path:githubkey#argocd-github-app-key>", "") # Remove placeholder
        print "  githubAppPrivateKey: |" # Add YAML block indicator
        n = split(APP_KEY, lines, "\n") # Split APP_KEY into lines
        for (i = 1; i <= n; i++) {
            print "    " lines[i] # Indent each line
        }
        next # Skip further processing for this line
    }
    if ($0 ~ /<path:githubkey#argocd-github-app-id>/) {
        gsub("<path:githubkey#argocd-github-app-id>", APP_ID)
    }
    print
}' argo-repository.yaml |\
kubectl apply -f -
# Install argo
echo "$ARGO_VALS" |\
  helm template argocd argo-cd \
  --repo $HELM_REPO \
  --version $ARGO_VERSION \
  --namespace $ARGO_NAMESPACE \
  --values - |\
  kubectl apply --namespace $ARGO_NAMESPACE --filename -

# Apply the app of apps
kubectl apply -f ../services/argocd/chart/templates/projects.yaml
kubectl apply -f ../services/argocd/chart/templates/apps.yaml

