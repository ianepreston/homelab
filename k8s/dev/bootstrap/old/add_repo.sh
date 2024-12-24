#!/bin/env bash
echo "This doesn't actually work without setting up port forwarding"
echo "Just do it in the UI but use this to get the key and reference the IDs"
if [ ! -f github.pem ]; then
	echo "Credentials file doesn't already exist, loading from Bitwarden."
	echo "Logging into bitwarden"
	bw login
	echo "Grabbing GitHub app key"
  echo $(bw get notes argocd-github-app-key) > github.pem
fi
echo "Add this repo through the UI"
echo "The app id is 1069435"
echo "The installation id is 57605564"
# This doesn't work without setting the path and port forwarding.
# If I'm going to do things manually might as well do it through the
# UI
# argocd repo add https://github.com/ianepreston/homelab.git \
#   --github-app-id 1069435\
#   --github-app-installation-id 57605564 \
#   --github-app-private-key-path github.pem
