# Installing xcp-ng

## Prep

If you've had proxmox or anything on it before make sure to wipe the partition table
to remove any zfs labels

## Installer

Nothing tricky here, just follow the prompts

## Add to XO

New -> Server. Give it a name, IP, username and password. Make sure to permit insecure
connection.

## Patch

Apply pool patches, restart hosts

## Add ISO SR

- Pick host
- Name: "Synology ISOs"
- Description: "ISOs stored on my Synology NAS"
- `NFS ISO` storage type
- Server: `laconia.ipreston.net`, hit the search icon
- Path: `/volume1/xcp`
- Subdirectory: `iso` hit the search icon again
- Create. Try making a VM just to see if you can see ISOs in the options

## Add Template SR

- Pick host
- Name: "Templates"
- Description: "Templates on Laconia"
- `NFS VDI` storage type
- Server: `laconia.ipreston.net`, hit the search icon
- Path: `/volume1/xcp`
- Subdirectory: `templates` hit the search icon again
- Create.

## Migrate templates from other hosts

- Home -> Templates
- Search for `full_disk` to find the ones I actually made
- Check the templates you want
- Click the little copy icon
- Delete `_COPY` from the name
- Copy to template storage on target host
- Repeat for any other hosts you've added
