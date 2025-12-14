# Plex Media Server Pack

This pack deploys [Plex Media Server](https://www.plex.tv/) to Nomad, with optional backup and version update jobs.

## Prerequisites

1. **Nomad Variables** - Set your Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```
   Get your claim token from [plex.tv/claim](https://www.plex.tv/claim/).

2. **Host Volumes** - Configure on your Nomad clients:
   - `plex-config` - Persistent configuration storage
   - `plex-transcode` - Temporary transcoding files

3. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library
   - `backup-drive` - Backup storage (if `enable_backup=true`)

4. **GPU (Optional)** - For hardware transcoding, ensure `/dev/dri` exists on host.

## Usage

```bash
# Deploy with defaults (GPU enabled, backup enabled, update enabled)
nomad-pack run plex --registry=media

# Deploy without GPU transcoding
nomad-pack run plex --registry=media -var gpu_transcoding=false

# Deploy without backup job
nomad-pack run plex --registry=media -var enable_backup=false

# Deploy without update job
nomad-pack run plex --registry=media -var enable_update=false

# Deploy with custom resources
nomad-pack run plex --registry=media -var cpu=8000 -var memory=8192
```

## Jobs Created

This pack creates up to 3 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `plex` | Main Plex Media Server service | Always created |
| `backup-plex` | Periodic backup of Plex config | `enable_backup` |
| `update-plex` | Periodic version check | `enable_update` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `plex` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Container image | `docker.io/plexinc/pms-docker:latest` |
| `gpu_transcoding` | Enable GPU passthrough | `true` |
| `plex_uid` | UID for Plex user | `1002` |
| `plex_gid` | GID for Plex group | `1001` |
| `timezone` | Container timezone | `America/New_York` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `port` | Plex port | `32400` |
| `media_volume_name` | CSI volume name | `media-drive` |
| `config_volume_name` | Config host volume | `plex-config` |
| `transcode_volume_name` | Transcode host volume | `plex-transcode` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `plex` |

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
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/plex` |

## Access

After deployment, access Plex at: `http://<nomad-client-ip>:32400/web`
