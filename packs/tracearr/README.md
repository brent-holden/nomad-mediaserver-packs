# Tracearr Pack

This pack deploys [Tracearr](https://tracearr.com) to Nomad, with optional backup, restore, and version update jobs. Tracearr is a real-time monitoring platform for Plex, Jellyfin, and Emby with session history, stream analytics, and account sharing detection. It can import history from Tautulli.

Tracearr needs TimescaleDB and Redis. The pack runs both as prestart sidecars in the same task group, bound to `127.0.0.1` on non-default ports so they don't collide with other databases on the host.

## Prerequisites

1. **Nomad Variables** - Set the Tracearr version and secrets:
   ```bash
   nomad var put nomad/jobs/tracearr version="latest"

   nomad var put nomad/jobs/tracearr/tracearr \
     jwt_secret="$(openssl rand -hex 32)" \
     cookie_secret="$(openssl rand -hex 32)" \
     db_password="$(openssl rand -hex 24)"
   ```
   The secrets live at the group-level path so the update job (which overwrites `nomad/jobs/tracearr`) can't clobber them. `db_password` is only used to initialize the database on first boot; changing it later requires changing the password in PostgreSQL too.

2. **Host Volumes** - Create on the Nomad client, owned by the UID each container runs as:

   | Volume | Mounted At | UID:GID | Mode |
   |--------|------------|---------|------|
   | `tracearr-config` | `/data/tracearr` | `1001:1001` | `0755` |
   | `tracearr-postgres` | `/home/postgres/pgdata/data` | `1000:1000` | `0700` |
   | `tracearr-redis` | `/data` | `999:1000` | `0755` |

   ```bash
   NODE_ID=$(nomad node status -short | grep ready | awk '{print $1}')

   cat <<EOF | nomad volume create -
   name      = "tracearr-postgres"
   type      = "host"
   plugin_id = "mkdir"
   node_id   = "$NODE_ID"

   capability {
     access_mode     = "single-node-multi-writer"
     attachment_mode = "file-system"
   }

   parameters {
     mode = "0700"
     uid  = "1000"
     gid  = "1000"
   }
   EOF
   ```

3. **CSI Volumes** - `backup-drive` for backup storage (if `enable_backup=true`)

## Usage

```bash
# Deploy with defaults (backup enabled, update enabled)
nomad-pack run packs/tracearr

# Deploy on a different port
nomad-pack run packs/tracearr -var port=3010

# Deploy without backup job
nomad-pack run packs/tracearr -var enable_backup=false
```

## Jobs Created

This pack creates up to 4 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `tracearr` | Tracearr with TimescaleDB and Redis sidecars | Always created |
| `tracearr-backup` | Periodic `pg_dump` of the database | `enable_backup` |
| `tracearr-update` | Periodic version check from GitHub releases | `enable_update` |
| `tracearr-restore` | Parameterized restore job (dispatch manually) | `enable_restore` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `tracearr` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Tracearr container image | `ghcr.io/connorgallopo/tracearr:latest` |
| `postgres_image` | TimescaleDB container image (pinned) | `docker.io/timescale/timescaledb-ha:pg18.4-ts2.29.1` |
| `redis_image` | Redis container image | `docker.io/library/redis:8-alpine` |
| `timezone` | Container timezone | `America/New_York` |
| `log_level` | Tracearr log level | `info` |
| `cpu` | Tracearr CPU allocation (MHz) | `1000` |
| `memory` | Tracearr memory allocation (MB) | `1024` |
| `postgres_cpu` | TimescaleDB CPU allocation (MHz) | `1000` |
| `postgres_memory` | TimescaleDB memory allocation (MB) | `1536` |
| `port` | Tracearr web UI port | `3005` |
| `postgres_port` | TimescaleDB port (127.0.0.1 only) | `5434` |
| `redis_port` | Redis port (127.0.0.1 only) | `6381` |
| `config_volume_name` | Tracearr data host volume | `tracearr-config` |
| `postgres_volume_name` | TimescaleDB host volume | `tracearr-postgres` |
| `redis_volume_name` | Redis host volume | `tracearr-redis` |
| `secrets_variable_path` | Nomad variable with `jwt_secret`, `cookie_secret`, `db_password` | `nomad/jobs/tracearr/tracearr` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `tracearr` |

### Backup Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_backup` | Enable backup job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` (2am daily) |
| `backup_volume_name` | CSI volume for backups | `backup-drive` |
| `backup_retention_days` | Days to retain backups | `14` |

### Update Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_update` | Enable update job | `true` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` (3am daily) |
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/tracearr` |

### Restore Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_restore` | Enable restore job | `false` |

## Backup and Restore

The backup job runs `pg_dump` from the same TimescaleDB image as the database, so client and server versions always match. Dumps land at `/backups/tracearr/YYYY-MM-DD/tracearr.dump`. The image cache in `tracearr-config` isn't backed up because Tracearr regenerates it.

The restore job loads the dump into a scratch database (wrapped in `timescaledb_pre_restore()`/`timescaledb_post_restore()`), then swaps it in for `tracearr`. Restart the Tracearr task afterwards:

```bash
nomad-pack run packs/tracearr -var enable_restore=true
nomad job dispatch -meta backup_date=2026-10-26 tracearr-restore   # omit -meta for latest
nomad alloc restart <alloc-id> tracearr
nomad-pack run packs/tracearr -var enable_restore=false
```

## Upgrading PostgreSQL

`postgres_image` is pinned on purpose. A minor TimescaleDB bump within PostgreSQL 18 is a variable change. A major PostgreSQL upgrade changes the on-disk format: take a backup, recreate the `tracearr-postgres` volume, deploy with the new image, and run the restore job.

## Access

After deployment, open `http://<nomad-client-ip>:3005` and connect your Plex, Jellyfin, or Emby server. To bring history over from Tautulli, use Tracearr's Tautulli importer.
