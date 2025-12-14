# Nomad Media Packs

A Nomad Pack registry for deploying media server applications to HashiCorp Nomad.

## Available Packs

| Pack | Description |
|------|-------------|
| `plex` | Plex Media Server with optional GPU transcoding, backup, and update jobs |
| `jellyfin` | Jellyfin Media Server with optional backup and update jobs |

Each pack includes:
- **Main service** - The media server itself
- **Backup job** - Periodic backup of configuration (enabled by default)
- **Update job** - Periodic version check (enabled by default)

## Prerequisites

- [Nomad](https://developer.hashicorp.com/nomad/install) cluster running
- [Nomad Pack](https://developer.hashicorp.com/nomad/docs/tools/nomad-pack) installed
- CSI plugin configured for media storage (SMB/CIFS recommended)
- Host volumes configured for application data

## Quick Start

### Add the Registry

```bash
nomad-pack registry add media https://github.com/brent-holden/nomad-media-packs
```

### Deploy Plex

```bash
# With GPU transcoding, backup, and update jobs (defaults)
nomad-pack run plex --registry=media

# Without GPU transcoding
nomad-pack run plex --registry=media -var gpu_transcoding=false

# Without backup job
nomad-pack run plex --registry=media -var enable_backup=false

# Without update job
nomad-pack run plex --registry=media -var enable_update=false

# With custom variables file
nomad-pack run plex --registry=media -f my-plex-vars.hcl
```

### Deploy Jellyfin

```bash
# With backup and update jobs (defaults)
nomad-pack run jellyfin --registry=media

# Without backup job
nomad-pack run jellyfin --registry=media -var enable_backup=false

# Service only (no backup or update)
nomad-pack run jellyfin --registry=media -var enable_backup=false -var enable_update=false
```

## Configuration

Each pack has configurable variables. View available variables:

```bash
nomad-pack info plex --registry=media
```

Generate a variables file:

```bash
nomad-pack generate var-file plex --registry=media > plex-vars.hcl
```

### Common Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `datacenters` | List of eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `timezone` | Timezone for schedules | `America/New_York` |

### Plex Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gpu_transcoding` | Enable GPU passthrough for hardware transcoding | `true` |
| `plex_uid` | UID for Plex user | `1002` |
| `plex_gid` | GID for Plex group | `1001` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `enable_backup` | Deploy backup job | `true` |
| `enable_update` | Deploy update job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` |
| `backup_retention_days` | Days to keep backups | `14` |

### Jellyfin Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `enable_backup` | Deploy backup job | `true` |
| `enable_update` | Deploy update job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` |
| `backup_retention_days` | Days to keep backups | `14` |

## Requirements

### Plex

1. Set up Nomad variables for Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```

2. Configure host volumes:
   - `plex-config` - Plex configuration data
   - `plex-transcode` - Transcoding temporary files

3. Configure CSI volumes:
   - `media-drive` - Media library storage
   - `backup-drive` - Backup storage (if `enable_backup=true`)

### Jellyfin

1. Configure host volumes:
   - `jellyfin-config` - Jellyfin configuration data
   - `jellyfin-cache` - Cache storage

2. Configure CSI volumes:
   - `media-drive` - Media library storage
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Destroying Deployments

```bash
nomad-pack destroy plex --registry=media
nomad-pack destroy jellyfin --registry=media
```

## License

MIT
