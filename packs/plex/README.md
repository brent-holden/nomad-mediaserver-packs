# Plex Media Server Pack

This pack deploys [Plex Media Server](https://www.plex.tv/) to Nomad.

## Prerequisites

1. **Nomad Variables** - Set your Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```
   Get your claim token from [plex.tv/claim](https://www.plex.tv/claim/).

2. **Host Volumes** - Configure on your Nomad clients:
   - `plex-config` - Persistent configuration storage
   - `plex-transcode` - Temporary transcoding files

3. **CSI Volume** - Configure media storage:
   - `media-drive` - Your media library

4. **GPU (Optional)** - For hardware transcoding, ensure `/dev/dri` exists on host.

## Usage

```bash
# Deploy with defaults (GPU enabled)
nomad-pack run plex --registry=media

# Deploy without GPU transcoding
nomad-pack run plex --registry=media -var gpu_transcoding=false

# Deploy with custom resources
nomad-pack run plex --registry=media -var cpu=8000 -var memory=8192
```

## Variables

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

## Access

After deployment, access Plex at: `http://<nomad-client-ip>:32400/web`
