# Nomad Media Packs

A Nomad Pack registry for deploying media server applications to HashiCorp Nomad.

## Available Packs

| Pack | Description |
|------|-------------|
| `plex` | Plex Media Server with optional GPU transcoding |
| `jellyfin` | Jellyfin Media Server |
| `update-plex` | Periodic job to check for Plex updates |
| `update-jellyfin` | Periodic job to check for Jellyfin updates |
| `backup-plex` | Periodic job to backup Plex configuration |
| `backup-jellyfin` | Periodic job to backup Jellyfin configuration |

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
# With GPU transcoding (default)
nomad-pack run plex --registry=media

# Without GPU transcoding
nomad-pack run plex --registry=media -var gpu_transcoding=false

# With custom variables file
nomad-pack run plex --registry=media -f my-plex-vars.hcl
```

### Deploy Jellyfin

```bash
nomad-pack run jellyfin --registry=media
```

### Deploy Update Jobs

```bash
# Check for Plex updates daily at 3am
nomad-pack run update-plex --registry=media

# Check for Jellyfin updates daily at 3am
nomad-pack run update-jellyfin --registry=media
```

### Deploy Backup Jobs

```bash
# Backup Plex config daily at 2am
nomad-pack run backup-plex --registry=media

# Backup Jellyfin config daily at 2am
nomad-pack run backup-jellyfin --registry=media
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

### Plex Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gpu_transcoding` | Enable GPU passthrough for hardware transcoding | `true` |
| `plex_uid` | UID for Plex user | `1002` |
| `plex_gid` | GID for Plex group | `1001` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |

### Jellyfin Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |

## Requirements

### Plex

1. Set up Nomad variables for Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```

2. Configure host volumes:
   - `plex-config` - Plex configuration data
   - `plex-transcode` - Transcoding temporary files

3. Configure CSI volume:
   - `media-drive` - Media library storage

### Jellyfin

1. Configure host volumes:
   - `jellyfin-config` - Jellyfin configuration data
   - `jellyfin-cache` - Cache storage

2. Configure CSI volume:
   - `media-drive` - Media library storage

## Destroying Deployments

```bash
nomad-pack destroy plex --registry=media
nomad-pack destroy jellyfin --registry=media
```

## License

MIT
