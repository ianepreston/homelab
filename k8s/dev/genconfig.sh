#/bin/env bash
talosctl gen config dk8s https://192.168.40.13:6443 \
    --with-secrets secrets.yaml \
    --config-patch @patches/allow-controlplane-workloads.yaml \
    --config-patch @patches/dhcp.yaml \
    --config-patch @patches/install-disk.yaml \
    --config-patch @patches/interface-names.yaml \
    --config-patch @patches/kubelet-certificates.yaml \
    --config-patch @patches/vip.yaml \
    --output rendered/
