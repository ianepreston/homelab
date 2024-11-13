!#/usr/bin/env bash
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
# Required to override PodSecurity
kubectl label namespace projectcontour pod-security.kubernetes.io/enforce=privileged --overwrite

