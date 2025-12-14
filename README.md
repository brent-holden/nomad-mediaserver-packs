# Nomad Media Packs

A Nomad Pack registry for deploying media server applications to HashiCorp Nomad.

## Available Packs

| Pack | Description |
|------|-------------|
| `plex` | Plex Media Server with optional GPU transcoding, backup, and update jobs |
| `jellyfin` | Jellyfin Media Server with optional GPU transcoding, backup, and update jobs |

Each pack includes:
- **Main service** - The media server itself
- **Backup job** - Periodic backup of configuration (enabled by default)
- **Update job** - Periodic version check (enabled by default)

## Prerequisites

- [Nomad](https://developer.hashicorp.com/nomad/install) cluster running
- [Nomad Pack](https://developer.hashicorp.com/nomad/docs/tools/nomad-pack) installed (v0.1.0+ with v2 template parser)
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
# With GPU transcoding, backup, and update jobs (defaults)
nomad-pack run jellyfin --registry=media

# Without GPU transcoding
nomad-pack run jellyfin --registry=media -var gpu_transcoding=false

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
| `gpu_transcoding` | Enable GPU passthrough for hardware transcoding | `true` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `enable_backup` | Deploy backup job | `true` |
| `enable_update` | Deploy update job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` |
| `backup_retention_days` | Days to keep backups | `14` |

## Volume Setup

Before deploying packs, you must configure the required volumes. See the `examples/` directory for reference configurations.

### CSI Volumes

These packs expect CSI volumes for shared storage. A CIFS/SMB CSI plugin is recommended for NAS-based media libraries.

1. **Install a CSI plugin** - See [nomad-media-infra](https://github.com/brent-holden/nomad-media-infra) for complete CSI setup including:
   - CSI controller and node plugin job specifications
   - Ansible playbooks for automated deployment
   - Volume registration templates

2. **Register CSI volumes:**
   ```bash
   # Edit examples/media-drive-volume.hcl with your fileserver details
   nomad volume register examples/media-drive-volume.hcl

   # If using backups, also register the backup volume
   nomad volume register examples/backup-drive-volume.hcl
   ```

   **Important:** For CIFS/SMB backup volumes, include `cache=none` and `nobrl` in the mount flags to ensure rsync operations work correctly:
   ```hcl
   mount_flags = ["uid=1002", "gid=1001", "file_mode=0644", "dir_mode=0755", "vers=3.0", "cache=none", "nobrl"]
   ```

| Volume | Purpose | Required |
|--------|---------|----------|
| `media-drive` | Shared media library | Yes |
| `backup-drive` | Backup storage | Only if `enable_backup=true` |

### Host Volumes

Host volumes provide persistent local storage for application configuration. Add these to your Nomad client configuration (see `examples/nomad-client-volumes.hcl`).

**Plex:**
| Volume | Purpose |
|--------|---------|
| `plex-config` | Plex configuration and database |
| `plex-transcode` | Temporary transcoding files |

**Jellyfin:**
| Volume | Purpose |
|--------|---------|
| `jellyfin-config` | Jellyfin configuration and database |
| `jellyfin-cache` | Cache for transcoding |

After adding host volumes, restart the Nomad client:
```bash
sudo systemctl restart nomad
```

## Application Setup

### Plex

1. Set up Nomad variables for Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```
   Get your claim token from [plex.tv/claim](https://www.plex.tv/claim/).

2. (Optional) For GPU transcoding, ensure `/dev/dri` exists on the host.

### Jellyfin

1. (Optional) For GPU transcoding (enabled by default), ensure `/dev/dri` exists on the host.

No additional setup required. Jellyfin will initialize on first run.

## Destroying Deployments

```bash
nomad-pack destroy plex --registry=media
nomad-pack destroy jellyfin --registry=media
```

## License

MIT
