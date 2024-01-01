# Updating Xen orchestra from source


## Main notes

Docs are [here](https://github.com/ronivay/XenOrchestraInstallerUpdater#installation)

- ssh into xo
- `su -`
- `cd /root/XenOrchestraInstallerUpdater`
- `./xo-install.sh`
- Hit `2` for update

## Side notes

There's an installer that builds this from running a script directly on an xcp-ng host
rather than doing all the hacky things I did to get this built. Should probably do that
in the future.

Had to resize the filesystem above 10G to have room for updates. I'm not sure why this
was so hard to do but I had to boot into a live CD, run `gparted`, resize the extended
partition and then the partition for the drive within that. Then boot back into the VM,
run `lvdisplay` to get the name of the vg and the lg (`xo-vg` and `root` in this case)
and then run `lvextend -l+100%FREE -r xo-vg/root` to actually free up the space.
