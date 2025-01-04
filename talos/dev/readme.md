# Bootstrapping Readme

## If you need to reset the cluster

```bash
talosctl reset --system-labels-to-wipe EPHEMERAL,STATE --reboot --graceful=false --wait=false -n 192.168.40.7
```
Repeat on all nodes.

## Apply config

```bash
talosctl apply -f rendered/controlplane.yaml -n 192.168.40.7 --insecure
```

Repeat for all nodes, replace with `worker.yaml` if you have both.

## Make sure everything is basically up

```bash
talosctl get members -n 192.168.40.11
```

Wait until that shows all of them.

## Bootstrap the cluster and install cilium

```bash
talosctl bootstrap -n 192.168.40.11
# Might have to wait a bit here or try again
./cilium.sh
```
