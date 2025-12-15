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

### Option A: Full Infrastructure with Ansible (Recommended)

The [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) repository provides complete infrastructure automation including Consul, Nomad, CSI plugins, and media server deployment.

```bash
# Clone the infrastructure repository
git clone https://github.com/brent-holden/nomad-mediaserver-infra.git
cd nomad-mediaserver-infra/ansible

# Configure your settings
cp group_vars/all.yml.example group_vars/all.yml
# Edit group_vars/all.yml with your NAS credentials and preferences

# Deploy everything (Consul, Nomad, CSI plugins, volumes, media server)
ansible-playbook -i inventory.ini site.yml

# Or deploy Jellyfin instead of Plex
ansible-playbook -i inventory.ini site.yml -e media_server=jellyfin
```

This option:
- Installs and configures Consul and Nomad
- Deploys the CIFS CSI plugin (controller and node)
- Creates all required volumes (CSI and host)
- Deploys the media server with backup, update, and restore jobs
- Provides a restore playbook for disaster recovery

### Option B: Using setup.sh (Existing Nomad Cluster)

If you already have a working Nomad cluster with the CSI plugin deployed, the `setup.sh` script can create volumes and deploy the media server.

**Prerequisites:**
- Nomad and Consul already running
- CSI plugin deployed (plugin ID: `cifs`)
- `nomad` and `nomad-pack` CLI tools installed

```bash
# Clone this repository
git clone https://github.com/brent-holden/nomad-mediaserver-packs.git
cd nomad-mediaserver-packs

# Set required environment variables
export NOMAD_ADDR=http://192.168.0.10:4646
export FILESERVER_PASSWORD=your-smb-password

# Optional: customize fileserver settings
export FILESERVER_IP=10.100.0.1
export FILESERVER_USERNAME=plex

# Run setup
./setup.sh plex              # Deploy Plex
./setup.sh jellyfin          # Deploy Jellyfin
./setup.sh plex --no-gpu     # Deploy without GPU transcoding
./setup.sh --help            # Show all options
```

**Note:** This option does NOT install Nomad, Consul, or the CSI plugin. Use Option A for a complete infrastructure setup.

### Option C: Manual Deployment

For advanced users who want full control over each step:

#### 1. Add the Registry

```bash
nomad-pack registry add mediaserver github.com/brent-holden/nomad-mediaserver-packs
```

#### 2. Create Volumes

See [Volume Requirements](#volume-requirements) for details on creating CSI and host volumes manually.

#### 3. Deploy

```bash
# Deploy Plex
nomad-pack run plex --registry=mediaserver

# Or deploy Jellyfin
nomad-pack run jellyfin --registry=mediaserver
```

### Access

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

**Important:** Host volumes must be created with `single-node-multi-writer` access mode to allow backup and restore jobs to access the volume while the main service is running. The job templates specify this access mode explicitly.

### CSI Plugin

The CSI SMB/CIFS plugin must be deployed before registering volumes. Example job files are provided in `examples/`:

```bash
# Deploy the CSI plugin (controller and node)
nomad job run examples/cifs-csi-plugin-controller.nomad
nomad job run examples/cifs-csi-plugin-node.nomad

# Verify plugin is healthy
nomad plugin status cifs
```

**Recommended image:** `registry.k8s.io/sig-storage/smbplugin:v1.19.1`

This is the Kubernetes SIG Storage SMB CSI driver, which provides reliable SMB/CIFS volume mounting for Nomad.

### CSI Volumes

CSI volumes provide access to network storage (SMB/CIFS shares):

| Volume | Purpose | Required |
|--------|---------|----------|
| `media-drive` | Media library (movies, TV, music) | Yes |
| `backup-drive` | Backup storage | If `enable_backup=true` |

Example volume definitions are in `examples/media-drive-volume.hcl` and `examples/backup-drive-volume.hcl`.

The CSI plugin ID is `cifs` by default. This can be changed via the `csi_plugin_id` variable if your plugin uses a different ID.

See [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) for complete infrastructure setup with Ansible.

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

### CSI Plugin Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `csi_plugin_id` | CSI plugin ID for volumes | `cifs` |
| `deploy_csi_volumes` | Deploy CSI volumes with pack | `false` |
| `csi_volume_username` | Username for CIFS/SMB auth | `plex` / `jellyfin` |
| `csi_volume_password` | Password for CIFS/SMB auth | `""` |
| `media_volume_source` | CIFS/SMB path for media | `//10.100.0.1/media` |
| `backup_volume_source` | CIFS/SMB path for backups | `//10.100.0.1/backups` |

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
nomad plugin status cifs
```

## Setup Script Reference

The `setup.sh` script provides a streamlined deployment for users who already have a working Nomad cluster with the CSI plugin deployed. It handles volume creation and media server deployment without requiring Ansible.

**Important:** This script does NOT install Nomad, Consul, or the CSI plugin. For complete infrastructure setup, use the [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) Ansible playbooks.

### What It Does

1. **Validates prerequisites** - Checks for Nomad connectivity, nomad-pack, and CSI plugin
2. **Creates CSI volumes** - Registers media-drive and backup-drive with proper mount options
3. **Creates host volumes** - Creates plex-config or jellyfin-config using the mkdir plugin
4. **Sets up registry** - Adds/updates the nomad-pack registry
5. **Deploys media server** - Runs nomad-pack with specified options
6. **Verifies deployment** - Waits for the job to be running

### Command Line Options

```bash
./setup.sh [plex|jellyfin] [options]
```

| Option | Description |
|--------|-------------|
| `plex` | Deploy Plex Media Server (default) |
| `jellyfin` | Deploy Jellyfin Media Server |
| `--no-gpu` | Disable GPU transcoding |
| `--no-backup` | Disable backup job |
| `--no-update` | Disable update job |
| `--no-restore` | Disable restore job |
| `--help`, `-h` | Show help message |

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NOMAD_ADDR` | Nomad server address | - | Yes |
| `FILESERVER_PASSWORD` | SMB/CIFS password | - | Yes |
| `FILESERVER_IP` | NAS/fileserver IP address | `10.100.0.1` | No |
| `FILESERVER_MEDIA_SHARE` | Media share name | `media` | No |
| `FILESERVER_BACKUP_SHARE` | Backup share name | `backups` | No |
| `FILESERVER_USERNAME` | SMB/CIFS username | `plex` | No |
| `USER_UID` | UID for volume ownership | `1002` | No |
| `GROUP_GID` | GID for volume ownership | `1001` | No |
| `CSI_PLUGIN_ID` | CSI plugin ID | `cifs` | No |
| `GPU_TRANSCODING` | Enable GPU transcoding | `true` | No |
| `ENABLE_BACKUP` | Enable backup job | `true` | No |
| `ENABLE_UPDATE` | Enable update job | `true` | No |
| `ENABLE_RESTORE` | Enable restore job | `true` | No |

### Examples

```bash
# Basic Plex deployment
NOMAD_ADDR=http://192.168.0.10:4646 \
FILESERVER_PASSWORD=secret \
./setup.sh plex

# Jellyfin without GPU
NOMAD_ADDR=http://192.168.0.10:4646 \
FILESERVER_PASSWORD=secret \
./setup.sh jellyfin --no-gpu

# Custom fileserver settings
NOMAD_ADDR=http://192.168.0.10:4646 \
FILESERVER_IP=192.168.1.100 \
FILESERVER_USERNAME=mediauser \
FILESERVER_PASSWORD=secret \
FILESERVER_MEDIA_SHARE=movies \
./setup.sh plex

# Minimal deployment (no backup/update/restore jobs)
NOMAD_ADDR=http://192.168.0.10:4646 \
FILESERVER_PASSWORD=secret \
./setup.sh plex --no-backup --no-update --no-restore
```

### Prerequisites

Before running `setup.sh`, ensure:

1. **Nomad cluster** is running with dynamic host volumes enabled (`host_volumes_dir` configured)
2. **CSI plugin** is deployed with plugin ID `cifs` (or set `CSI_PLUGIN_ID` to match your plugin)
3. **NAS/fileserver** is accessible with SMB/CIFS shares configured
4. **nomad** and **nomad-pack** CLI tools are installed

## Related Repositories

- [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) - Ansible playbooks for complete infrastructure deployment including CSI plugins, volumes, and automated restore

## License

MIT
