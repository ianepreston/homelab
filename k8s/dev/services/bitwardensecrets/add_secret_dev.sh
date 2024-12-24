#!/bin/env bash
kubectl create secret generic bw-auth-token -n sm-operator-system --from-literal=token="$(cat bwtokendev.txt)"
