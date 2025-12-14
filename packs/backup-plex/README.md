# Backup Plex Pack

This pack deploys a periodic backup job for [Plex Media Server](https://www.plex.tv/) configuration.

## Prerequisites

1. **Host Volume** - The `plex-config` host volume must be configured on your Nomad clients.

2. **CSI Volume** - The `backup-drive` CSI volume must be registered for backup storage.

## What Gets Backed Up

- Plex database files (`Plug-in Support/Databases/`)
- Preferences.xml configuration file

## Usage

```bash
# Deploy with defaults (daily at 2am, 14 day retention)
nomad-pack run backup-plex --registry=media

# Deploy with custom schedule
nomad-pack run backup-plex --registry=media -var cron_schedule="0 4 * * *"

# Deploy with custom retention
nomad-pack run backup-plex --registry=media -var retention_days=30
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `backup-plex` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `cron_schedule` | Backup schedule (cron format) | `0 2 * * *` |
| `timezone` | Timezone for schedule | `America/New_York` |
| `image` | Container image | `docker.io/debian:bookworm-slim` |
| `config_volume_name` | Host volume for Plex config | `plex-config` |
| `backup_volume_name` | CSI volume for backups | `backup-drive` |
| `retention_days` | Days to retain backups | `14` |
| `cpu` | CPU allocation (MHz) | `500` |
| `memory` | Memory allocation (MB) | `512` |

## Backup Location

Backups are stored at `/backups/plex/YYYY-MM-DD/` on the backup volume.
