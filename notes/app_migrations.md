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

## Postgres migration

Using Miniflux as an example

- ssh into the host with the container
- stop the app container, keep the db container running `docker stop miniflux`
- dump the database to the host: `docker exec -t miniflux-postgres pg_dumpall -c -U miniflux > minflux_dump.sql`
- copy the data to a new host if we're doing a host as well as or instead of a version migration
- Make sure the app container isn't running and doesn't start until the end. Comment out that part of the playbook.
  If you don't do this part you might get some database init scripts running that you'll have to clean out first. Annoying.
- Get a postgres container running the new version in the new host ready, with ansible or updating the tag or whatever.
- Dump the migration script into the database `cat miniflux_dump.sql | docker exec -i miniflux-postgres psql -U miniflux`
- Reset the password. Passwords aren't migrated in the dump but this seems necessary even
  if you set the same user and password in `POSTGRES_PASSWORD` and `POSTGRES_USER` variables.
  - connect to the container: `docker exec -it miniflux-postgres bash`
  - connect to the database: `psql miniflux -U miniflux`
  - reset the password: `alter USER miniflux WITH PASSWORD '<PASSWORD HERE';`
  - exit postgres and the container
- Start the app container
