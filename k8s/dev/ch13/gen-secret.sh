#!/bin/env bash
kubectl create secret generic kuard-tls \
  --from-file=kuard.crt \
  --from-file=kuard.key \
  --dry-run=client \
  -o yaml > kuard-tsl-secret.yaml
