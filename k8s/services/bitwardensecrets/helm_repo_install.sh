#!/bin/env bash
helm repo add bitwarden https://charts.bitwarden.com/
helm repo update
echo "helm show values bitwarden/sm-operator --devel > my-values.yaml"
echo "is what you would run if I wasn't tracking that output in git"
