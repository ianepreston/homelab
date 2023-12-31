# Docs on migrating apps

How to do backups/restores on my various apps.

## Docker volume migration

Generally I should probably just do this if it will work.

- ssh to the host with the volume I want to migrate, call it `source_host`.
- Identify the volume I want to migrate, call it `target_vol`
- Stop the container that's attached to the volume `docker stop <target_container>`
- For each volume, create a backup. You can do this by creating a tarball of the volume's contents.
  - `docker run --rm -v target_vol:/volume -v $(pwd):/backup ubuntu tar cvf /backup/target_vol_backup.tar /volume`
  - This command runs a temporary Ubuntu container, mounts the volume and a local
    directory for the backup, and then creates a tarball of the volume.
- Copy the backup over to the new host with scp, call this `target_host`
- ssh to `target_host`
- Create the new volume with `docker volume create target_vol`
- Restore the backup:
  - `docker run --rm -v target_vol:/volume -v <folder with backup>:/backup ubuntu tar xvf /backup/target_vol_backup.tar -C /volume`
