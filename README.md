# Nomad Media Server Packs

Nomad Pack templates for deploying Plex and Jellyfin media servers to HashiCorp Nomad.

## Features

Each pack includes:

- **Main service** - Media server with GPU transcoding support
- **Backup job** - Periodic backup of configuration to network storage
- **Update job** - Periodic version check and Nomad variable updates
- **Restore job** - On-demand restore from backups

## Available Packs

| Pack | Description |
|------|-------------|
| `plex` | Plex Media Server |
| `jellyfin` | Jellyfin Media Server |

## Prerequisites

- [Nomad 1.10+](https://developer.hashicorp.com/nomad/install) - Required for dynamic host volumes
- [Nomad Pack](https://developer.hashicorp.com/nomad/docs/tools/nomad-pack) - v0.1.0+ with v2 template parser
- [CSI volumes](#csi-volumes) - For media and backup storage
- [Podman driver](https://github.com/hashicorp/nomad-driver-podman) - Container runtime

## Quick Start

### 1. Add the Registry

```bash
nomad-pack registry add mediaserver github.com/brent-holden/nomad-mediaserver-packs
```

### 2. Deploy

```bash
# Deploy Plex
nomad-pack run plex --registry=mediaserver

# Or deploy Jellyfin
nomad-pack run jellyfin --registry=mediaserver
```

### 3. Access

- Plex: http://your-server:32400
- Jellyfin: http://your-server:8096

## Volume Requirements

### Dynamic Host Volumes

These packs use Nomad's dynamic host volumes (requires Nomad 1.10+). The Nomad client must be configured with:

```hcl
client {
  host_volumes_dir = "/opt/nomad/volumes"
}
```

The `deploy-media-server.yml` playbook in [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) creates the host volumes automatically using the `mkdir` plugin:

| Pack | Volume | Purpose |
|------|--------|---------|
| Plex | `plex-config` | Configuration, database, and metadata |
| Jellyfin | `jellyfin-config` | Configuration, database, and metadata |

### CSI Volumes

CSI volumes provide access to network storage (SMB/CIFS shares):

| Volume | Purpose | Required |
|--------|---------|----------|
| `media-drive` | Media library (movies, TV, music) | Yes |
| `backup-drive` | Backup storage | If `enable_backup=true` |

See [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) for complete CSI plugin setup.

## Configuration

### View Available Variables

```bash
nomad-pack info plex --registry=mediaserver
```

### Common Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the main job | `plex` / `jellyfin` |
| `datacenters` | List of eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `timezone` | Timezone for schedules | `America/New_York` |

### Feature Toggles

| Variable | Description | Default |
|----------|-------------|---------|
| `gpu_transcoding` | Enable GPU passthrough (`/dev/dri`) | `true` |
| `enable_backup` | Deploy periodic backup job | `true` |
| `enable_update` | Deploy periodic update job | `true` |
| `enable_restore` | Deploy parameterized restore job | `false` |

### Resource Allocation

| Variable | Description | Default |
|----------|-------------|---------|
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |

### Plex-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `plex_uid` | UID for Plex process | `1002` |
| `plex_gid` | GID for Plex process | `1001` |
| `port` | Plex web interface port | `32400` |

### Jellyfin-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `jellyfin_uid` | UID for Jellyfin process | `1002` |
| `jellyfin_gid` | GID for Jellyfin process | `1001` |
| `http_port` | Jellyfin web interface port | `8096` |
| `discovery_port` | Jellyfin discovery port | `7359` |

### Backup/Update Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `backup_cron_schedule` | Backup schedule (cron format) | `0 2 * * *` (2am daily) |
| `update_cron_schedule` | Update check schedule | `0 3 * * *` (3am daily) |
| `backup_retention_days` | Days to keep backups | `14` |
| `backup_volume_name` | CSI volume for backups | `backup-drive` |

### Volume Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `config_volume_name` | Host volume for config | `plex-config` / `jellyfin-config` |
| `media_volume_name` | CSI volume for media | `media-drive` |

## Deployment Examples

### Basic Deployment

```bash
nomad-pack run plex --registry=mediaserver
```

### Without GPU Transcoding

```bash
nomad-pack run plex --registry=mediaserver -var gpu_transcoding=false
```

### With Restore Job Enabled

```bash
nomad-pack run plex --registry=mediaserver -var enable_restore=true
```

### Minimal Deployment (No Extra Jobs)

```bash
nomad-pack run plex --registry=mediaserver \
  -var enable_backup=false \
  -var enable_update=false
```

### Custom Resources

```bash
nomad-pack run jellyfin --registry=mediaserver \
  -var cpu=8000 \
  -var memory=8192
```

### Using a Variables File

```bash
# Generate template
nomad-pack generate var-file plex --registry=mediaserver > plex-vars.hcl

# Edit plex-vars.hcl with your settings

# Deploy with file
nomad-pack run plex --registry=mediaserver -f plex-vars.hcl
```

## Jobs Created

### Plex Pack

| Job | Type | Description |
|-----|------|-------------|
| `plex` | service | Main Plex Media Server |
| `backup-plex` | batch/periodic | Daily backup (if enabled) |
| `update-plex` | batch/periodic | Daily version check (if enabled) |
| `restore-plex` | batch/parameterized | On-demand restore (if enabled) |

### Jellyfin Pack

| Job | Type | Description |
|-----|------|-------------|
| `jellyfin` | service | Main Jellyfin server |
| `backup-jellyfin` | batch/periodic | Daily backup (if enabled) |
| `update-jellyfin` | batch/periodic | Daily version check (if enabled) |
| `restore-jellyfin` | batch/parameterized | On-demand restore (if enabled) |

## Backup and Restore

### What Gets Backed Up

- **Plex**: `Plug-in Support/Databases/*`, `Preferences.xml`
- **Jellyfin**: `data/*`, `config/*`

Backups are stored in the backup CSI volume at `/{plex,jellyfin}/YYYY-MM-DD/`.

### Manual Backup

Backups run automatically at 2am. To trigger manually:

```bash
nomad job periodic force backup-plex
```

### Restore from Backup

The restore job is a parameterized batch job that must be dispatched manually:

```bash
# Restore from latest backup
nomad job dispatch restore-plex

# Restore from specific date
nomad job dispatch -meta backup_date=2025-01-15 restore-plex
```

**Important:** Stop the media server before restoring, then restart it after:

```bash
# Stop
nomad job stop plex

# Restore
nomad job dispatch restore-plex

# Wait for restore to complete, then restart
nomad-pack run plex --registry=mediaserver -var enable_restore=true
```

Or use the `restore-media-server.yml` Ansible playbook from [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) which handles this automatically.

## Plex Setup

### Claim Token

Set up Nomad variables for the Plex claim token:

```bash
# Get claim token from https://plex.tv/claim (valid 4 minutes)
nomad var put nomad/jobs/plex claim_token="claim-xxxxxxxxxxxx" version="latest"
```

The claim token is only needed for initial setup. After Plex is claimed, it persists in the configuration.

### GPU Transcoding

Ensure `/dev/dri` exists on the host and is accessible. The container maps `/dev/dri:/dev/dri` when `gpu_transcoding=true`.

## Jellyfin Setup

No special setup required. Jellyfin initializes on first run.

For GPU transcoding, ensure `/dev/dri` exists on the host.

## Destroying Deployments

```bash
nomad-pack destroy plex --registry=mediaserver
nomad-pack destroy jellyfin --registry=mediaserver
```

## Troubleshooting

### Check Job Status

```bash
nomad job status plex
nomad alloc logs -job plex
```

### Check Volume Mounts

```bash
nomad volume status
nomad volume status -type host
```

### View Backup Logs

```bash
nomad alloc logs -job backup-plex
```

### CSI Plugin Issues

```bash
nomad plugin status smb
```

## Related Repositories

- [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) - Ansible playbooks for complete infrastructure deployment including CSI plugins, volumes, and automated restore

## License

MIT
