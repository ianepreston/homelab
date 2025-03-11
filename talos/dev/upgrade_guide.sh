#!/bin/env bash
set -e
echo "Installer script for Talos and k8s"
echo "Will just output the commands to run, not run them"
TALOS_VER=v1.9.4
K8S_VER=1.32.2
SCHEMATIC=$(curl -s -X POST --data-binary @image.yaml https://factory.talos.dev/schematics | jq -r '.id')
FACTORY_URL="factory.talos.dev/installer/${SCHEMATIC}:${TALOS_VER}"
TALOS_CP_1=192.168.40.7
TALOS_CP_2=192.168.40.9
TALOS_CP_3=192.168.40.11
ISO="https://factory.talos.dev/image/${SCHEMATIC}/${VERSION}metal-amd64.iso"
echo "----------------------------------------------------------------------"
echo "ISO URL:"
echo "----------------------------------------------------------------------"
echo $ISO
echo "----------------------------------------------------------------------"
echo "Upgrade Talos"
echo "----------------------------------------------------------------------"
echo "talosctl upgrade --debug --stage --preserve --nodes $TALOS_CP_1 --image $FACTORY_URL"
echo "talosctl upgrade --debug --stage --preserve --nodes $TALOS_CP_2 --image $FACTORY_URL"
echo "talosctl upgrade --debug --stage --preserve --nodes $TALOS_CP_3 --image $FACTORY_URL"
echo "----------------------------------------------------------------------"
echo "Upgrade Kubernetes"
echo "----------------------------------------------------------------------"
echo "talosctl --nodes $TALOS_CP_1 upgrade-k8s --to $K8S_VER --dry-run"
echo "talosctl --nodes $TALOS_CP_1 upgrade-k8s --to $K8S_VER"
