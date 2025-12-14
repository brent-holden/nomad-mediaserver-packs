# Jellyfin Media Server Pack

This pack deploys [Jellyfin](https://jellyfin.org/) to Nomad, with optional backup and version update jobs.

## Prerequisites

1. **Host Volumes** - Configure on your Nomad clients:
   - `jellyfin-config` - Persistent configuration storage
   - `jellyfin-cache` - Cache storage for transcoding

2. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library
   - `backup-drive` - Backup storage (if `enable_backup=true`)

3. **GPU (Optional)** - For hardware transcoding, ensure `/dev/dri` exists on host.

## Usage

```bash
# Deploy with defaults (backup enabled, update enabled)
nomad-pack run jellyfin --registry=media

# Deploy with GPU transcoding
nomad-pack run jellyfin --registry=media -var gpu_transcoding=true

# Deploy without backup job
nomad-pack run jellyfin --registry=media -var enable_backup=false

# Deploy without update job
nomad-pack run jellyfin --registry=media -var enable_update=false

# Deploy with custom resources
nomad-pack run jellyfin --registry=media -var cpu=8000 -var memory=8192
```

## Jobs Created

This pack creates up to 3 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `jellyfin` | Main Jellyfin service | Always created |
| `backup-jellyfin` | Periodic backup of Jellyfin config | `enable_backup` |
| `update-jellyfin` | Periodic version check | `enable_update` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `jellyfin` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Container image | `docker.io/jellyfin/jellyfin:latest` |
| `gpu_transcoding` | Enable GPU passthrough | `false` |
| `timezone` | Container timezone | `America/New_York` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `http_port` | HTTP port | `8096` |
| `discovery_port` | Discovery port | `7359` |
| `media_volume_name` | CSI volume name | `media-drive` |
| `config_volume_name` | Config host volume | `jellyfin-config` |
| `cache_volume_name` | Cache host volume | `jellyfin-cache` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `jellyfin` |

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
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/jellyfin` |

## Access

After deployment, access Jellyfin at: `http://<nomad-client-ip>:8096`
