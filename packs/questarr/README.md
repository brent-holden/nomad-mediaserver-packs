# Questarr Pack

This pack deploys [Questarr](https://github.com/Doezer/Questarr) to Nomad, with optional backup, restore, and version update jobs. Questarr is a self-hosted game library manager in the style of the *arr apps: game discovery (IGDB, RSS, Steam wishlist sync), backlog tracking, and automated downloads via your indexers and download clients.

Questarr stores everything (SQLite database, config, and encryption keys) in a single data directory, which the pack persists on a host volume. It runs as a single replica with SQLite by default.

## Prerequisites

1. **Nomad Variables** - Set the Questarr version:
   ```bash
   nomad var put nomad/jobs/questarr version="latest"
   ```

2. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `questarr-config` - Persistent data storage (SQLite database, config, encryption keys)

3. **CSI Volumes** - `backup-drive` for backup storage (if `enable_backup=true`)

## Usage

```bash
# Deploy with defaults (backup enabled, update enabled)
nomad-pack run packs/questarr

# Deploy on a different port (Questarr's own default is 5000, which FileFlows uses)
nomad-pack run packs/questarr -var port=5060

# Deploy without backup job
nomad-pack run packs/questarr -var enable_backup=false
```

## Jobs Created

This pack creates up to 4 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `questarr` | Main Questarr service | Always created |
| `questarr-backup` | Periodic backup of the data directory | `enable_backup` |
| `questarr-update` | Periodic version check from GitHub releases | `enable_update` |
| `questarr-restore` | Parameterized restore job (dispatch manually) | `enable_restore` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `questarr` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Questarr container image | `ghcr.io/doezer/questarr:latest` |
| `questarr_uid` | UID for Questarr process (PUID) | `1002` |
| `questarr_gid` | GID for Questarr process (PGID) | `1001` |
| `timezone` | Container timezone | `America/New_York` |
| `cpu` | CPU allocation (MHz) | `500` |
| `memory` | Memory allocation (MB) | `512` |
| `port` | Questarr web UI port | `5050` |
| `config_volume_name` | Host volume for data | `questarr-config` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `questarr` |

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
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/questarr` |

### Restore Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_restore` | Enable restore job | `false` |

## Backup and Restore

The backup job rsyncs the whole data directory to `/backups/questarr/YYYY-MM-DD/`, capturing the SQLite database, config, and encryption keys.

```bash
nomad-pack run packs/questarr -var enable_restore=true
nomad job dispatch -meta backup_date=2026-10-27 questarr-restore   # omit -meta for latest
nomad-pack run packs/questarr -var enable_restore=false
```

## Post-Deployment Setup

After deployment, open the web UI and:

1. Create an admin account
2. Configure IGDB credentials (Client ID and Client Secret from the Twitch Developer Console)
3. Configure indexers (Prowlarr sync for Torznab/Newznab) and download clients (qBittorrent, SABnzbd, etc.)

## Access

After deployment, open `http://<nomad-client-ip>:5050` and complete the first-run setup.
