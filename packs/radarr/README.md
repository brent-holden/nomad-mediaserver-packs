# Radarr Pack

This pack deploys [Radarr](https://radarr.video/) to Nomad, with optional backup and version update jobs.

Radarr is a movie collection manager for Usenet and BitTorrent users. It monitors multiple RSS feeds for new movies and interfaces with clients and indexers to grab, sort, and rename them.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `radarr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library (movies and downloads)
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Media Volume Structure

The `media-drive` CSI volume is mounted at `/media` inside the container. Your volume should have the following directory structure:

```
/media
├── downloads/
│   └── movies/        # Download client puts completed movies here
└── movies/            # Radarr moves/hardlinks finished movies here
```

### Radarr Configuration

After deployment, configure these paths in Radarr's UI:

1. **Settings → Media Management → Root Folders**
   - Add `/media/movies` as the root folder for your movie library

2. **Settings → Download Clients**
   - Configure your download client (e.g., SABnzbd, qBittorrent)
   - The download client should save completed movies to `/media/downloads/movies`

### Why This Structure?

Using a single volume with subdirectories for both downloads and media allows Radarr to use **hardlinks** instead of copying files. This:
- Saves disk space (no duplicate files during seeding)
- Makes imports instant (no file copy time)
- Requires downloads and media to be on the same filesystem

If your download client runs in a separate container, ensure it also mounts the same `media-drive` CSI volume.

## Usage

```bash
# Deploy with defaults (backup enabled, update enabled)
nomad-pack run radarr --registry=mediaserver

# Deploy without backup job
nomad-pack run radarr --registry=mediaserver -var enable_backup=false

# Deploy without update job
nomad-pack run radarr --registry=mediaserver -var enable_update=false

# Deploy with custom UID/GID
nomad-pack run radarr --registry=mediaserver -var radarr_uid=1100 -var radarr_gid=1100

# Deploy with custom resources
nomad-pack run radarr --registry=mediaserver -var cpu=1000 -var memory=2048
```

## Jobs Created

This pack creates up to 3 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `radarr` | Main Radarr service | Always created |
| `backup-radarr` | Periodic backup of Radarr config | `enable_backup` |
| `update-radarr` | Periodic version check | `enable_update` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `radarr` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Container image | `docker.io/linuxserver/radarr:latest` |
| `radarr_uid` | UID for Radarr user (PUID) | `1000` |
| `radarr_gid` | GID for Radarr group (PGID) | `1000` |
| `timezone` | Container timezone | `America/New_York` |
| `cpu` | CPU allocation (MHz) | `500` |
| `memory` | Memory allocation (MB) | `1024` |
| `port` | Radarr port | `7878` |
| `config_volume_name` | Config host volume | `radarr-config` |
| `media_volume_name` | CSI volume for media and downloads | `media-drive` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `radarr` |

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
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/radarr` |

## Backup Strategy

The backup job copies the following files:
- `radarr.db` - Main database (movie library, settings)
- `config.xml` - Configuration file
- `Backups/` - Radarr's internal backup directory

Backups are stored in `/backups/radarr/YYYY-MM-DD/` and old backups are automatically cleaned up based on `backup_retention_days`.

## Update Strategy

The update job:
1. Fetches the latest Radarr version from GitHub releases API
2. Stores the version in a Nomad variable at `nomad/jobs/radarr`

Note: The update job tracks versions but does not automatically restart the service. The linuxserver/radarr image with `:latest` tag will pull new versions when the container restarts.

## Access

After deployment, access Radarr at: `http://<nomad-client-ip>:7878`
