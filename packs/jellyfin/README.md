# Jellyfin Media Server Pack

This pack deploys [Jellyfin](https://jellyfin.org/) to Nomad.

## Prerequisites

1. **Host Volumes** - Configure on your Nomad clients:
   - `jellyfin-config` - Persistent configuration storage
   - `jellyfin-cache` - Cache storage for transcoding

2. **CSI Volume** - Configure media storage:
   - `media-drive` - Your media library

## Usage

```bash
# Deploy with defaults
nomad-pack run jellyfin --registry=media

# Deploy with custom resources
nomad-pack run jellyfin --registry=media -var cpu=8000 -var memory=8192
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `jellyfin` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Container image | `docker.io/jellyfin/jellyfin:latest` |
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

## Access

After deployment, access Jellyfin at: `http://<nomad-client-ip>:8096`
