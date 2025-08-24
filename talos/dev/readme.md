# Bootstrapping Readme

## If you need to reset the cluster

```bash
talosctl reset --system-labels-to-wipe EPHEMERAL,STATE --reboot --graceful=false --wait=false -n 192.168.40.7
```
Repeat on all nodes.

## Apply config

```bash
talhelper gencommand apply # add the --insecure flag
```

## Make sure everything is basically up

```bash
talosctl get members -n 192.168.40.11
```

Wait until that shows all of them.

## Bootstrap the cluster and install cilium

```bash
talhelper gencommand bootstrap; # then run the output
# Might have to wait a bit here or try again
./cilium.sh
```

## Get your kubeconfig back

```bash
talosctl -n 192.168.40.7 kubeconfig
```
