# Nomad Media Server Packs

Nomad Pack templates for deploying media servers and related services to HashiCorp Nomad.

## Features

Each pack includes:

- **Main service** - Media server with GPU transcoding support
- **Backup job** - Periodic backup of configuration to network storage
- **Update job** - Periodic version check and Nomad variable updates
- **Restore job** - On-demand restore from backups

## Available Packs

| Pack | Description | Port |
|------|-------------|------|
| `plex` | Plex Media Server | 32400 |
| `jellyfin` | Jellyfin Media Server | 8096 |
| `radarr` | Radarr - Movie collection manager | 7878 |
| `sonarr` | Sonarr - TV series collection manager | 8989 |
| `lidarr` | Lidarr - Music collection manager | 8686 |
| `prowlarr` | Prowlarr - Indexer manager | 9696 |
| `overseerr` | Overseerr - Request management for Plex | 5055 |
| `tautulli` | Tautulli - Plex monitoring and statistics | 8181 |
| `sabnzbd` | SABnzbd - Usenet download client | 8080 |

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
- Radarr: http://your-server:7878
- Sonarr: http://your-server:8989
- Lidarr: http://your-server:8686
- Prowlarr: http://your-server:9696
- Overseerr: http://your-server:5055
- Tautulli: http://your-server:8181
- SABnzbd: http://your-server:8080

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
| Radarr | `radarr-config` | Configuration and database |
| Sonarr | `sonarr-config` | Configuration and database |
| Lidarr | `lidarr-config` | Configuration and database |
| Prowlarr | `prowlarr-config` | Configuration and database |
| Overseerr | `overseerr-config` | Configuration and database |
| Tautulli | `tautulli-config` | Configuration and database |
| SABnzbd | `sabnzbd-config` | Configuration and database |

**Important:** Host volumes must be created with `single-node-multi-writer` access mode to allow backup and restore jobs to access the volume while the main service is running. The job templates specify this access mode explicitly.

#### Creating Host Volumes Manually

If not using Ansible, create host volumes with:

```bash
# Get your node ID
NODE_ID=$(nomad node status -short | grep ready | awk '{print $1}')

# Create a host volume
cat <<EOF | nomad volume create -
name      = "radarr-config"
type      = "host"
plugin_id = "mkdir"
node_id   = "$NODE_ID"

capability {
  access_mode     = "single-node-multi-writer"
  attachment_mode = "file-system"
}
EOF
```

Repeat for each service you want to deploy, changing the volume name accordingly.

### CSI Plugin

The CSI SMB/CIFS plugin must be deployed before registering volumes. See [nomad-csi-cifs](https://github.com/brent-holden/nomad-csi-cifs) for plugin deployment and volume configuration.

```bash
# Clone the CSI repo
git clone https://github.com/brent-holden/nomad-csi-cifs.git
cd nomad-csi-cifs

# Deploy the CSI plugin
nomad job run jobs/csi-controller.nomad
nomad job run jobs/csi-node.nomad

# Verify plugin is healthy
nomad plugin status cifs
```

### CSI Volumes

CSI volumes provide access to network storage (SMB/CIFS shares):

| Volume | Purpose | Required |
|--------|---------|----------|
| `media-drive` | Media library (movies, TV, music) | Yes |
| `backup-drive` | Backup storage | If `enable_backup=true` |

Volume examples are available in the [nomad-csi-cifs](https://github.com/brent-holden/nomad-csi-cifs) repository.

The CSI plugin ID is `cifs` by default. This can be changed via the `csi_plugin_id` variable if your plugin uses a different ID.

See [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) for complete infrastructure setup with Ansible.

### Media Volume Directory Structure

The `media-drive` CSI volume is mounted at `/media` inside containers. The expected directory structure is:

```
/media
├── books/                      # Books library (for Readarr)
├── downloads/
│   ├── complete/
│   │   ├── movies/             # Completed movie downloads
│   │   ├── tv/                 # Completed TV downloads
│   │   └── other/              # Other completed downloads
│   └── incomplete/             # Downloads in progress
├── movies/                     # Movie library (for Radarr)
└── tv/                         # TV library (for Sonarr)
```

This structure allows all media services to share a single volume while maintaining organization. Using a single volume for both downloads and media libraries enables **hardlinks** instead of file copies, which:
- Saves disk space (no duplicate files during seeding)
- Makes imports instant (no file copy time)
- Requires downloads and media to be on the same filesystem

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

### User/Group Configuration

All packs default to the same UID (1002) and GID (1001) for consistent file permissions across shared CSI volumes. This ensures that files created by one service (e.g., SABnzbd downloads) can be read and modified by other services (e.g., Radarr importing to Plex library).

| Variable | Description | Default |
|----------|-------------|---------|
| `{service}_uid` | UID for the service process | `1002` |
| `{service}_gid` | GID for the service process | `1001` |

**Important:** If you change the UID/GID for one service, you should change it for all services that share the media volume to avoid permission issues.

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

### Radarr-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `radarr_uid` | UID for Radarr process (PUID) | `1002` |
| `radarr_gid` | GID for Radarr process (PGID) | `1001` |
| `port` | Radarr web interface port | `7878` |

### Sonarr-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `sonarr_uid` | UID for Sonarr process (PUID) | `1002` |
| `sonarr_gid` | GID for Sonarr process (PGID) | `1001` |
| `port` | Sonarr web interface port | `8989` |

### Lidarr-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `lidarr_uid` | UID for Lidarr process (PUID) | `1002` |
| `lidarr_gid` | GID for Lidarr process (PGID) | `1001` |
| `port` | Lidarr web interface port | `8686` |

### Prowlarr-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `prowlarr_uid` | UID for Prowlarr process (PUID) | `1002` |
| `prowlarr_gid` | GID for Prowlarr process (PGID) | `1001` |
| `port` | Prowlarr web interface port | `9696` |

### Overseerr-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `overseerr_uid` | UID for Overseerr process (PUID) | `1002` |
| `overseerr_gid` | GID for Overseerr process (PGID) | `1001` |
| `port` | Overseerr web interface port | `5055` |

### Tautulli-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `tautulli_uid` | UID for Tautulli process (PUID) | `1002` |
| `tautulli_gid` | GID for Tautulli process (PGID) | `1001` |
| `port` | Tautulli web interface port | `8181` |

### SABnzbd-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `sabnzbd_uid` | UID for SABnzbd process (PUID) | `1002` |
| `sabnzbd_gid` | GID for SABnzbd process (PGID) | `1001` |
| `port` | SABnzbd web interface port | `8080` |

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

Each pack creates multiple Nomad jobs following the naming convention `{service}-{type}`:
- `{service}` - Main service job
- `{service}-backup` - Periodic backup job
- `{service}-update` - Periodic version check job
- `{service}-restore` - On-demand restore job (if enabled)

### Plex Pack

| Job | Type | Description |
|-----|------|-------------|
| `plex` | service | Main Plex Media Server |
| `plex-backup` | batch/periodic | Daily backup (if enabled) |
| `plex-update` | batch/periodic | Daily version check (if enabled) |
| `plex-restore` | batch/parameterized | On-demand restore (if enabled) |

### Jellyfin Pack

| Job | Type | Description |
|-----|------|-------------|
| `jellyfin` | service | Main Jellyfin server |
| `jellyfin-backup` | batch/periodic | Daily backup (if enabled) |
| `jellyfin-update` | batch/periodic | Daily version check (if enabled) |
| `jellyfin-restore` | batch/parameterized | On-demand restore (if enabled) |

### Radarr Pack

| Job | Type | Description |
|-----|------|-------------|
| `radarr` | service | Main Radarr service |
| `radarr-backup` | batch/periodic | Daily backup (if enabled) |
| `radarr-update` | batch/periodic | Daily version check (if enabled) |
| `radarr-restore` | batch/parameterized | On-demand restore (if enabled) |

### Sonarr Pack

| Job | Type | Description |
|-----|------|-------------|
| `sonarr` | service | Main Sonarr service |
| `sonarr-backup` | batch/periodic | Daily backup (if enabled) |
| `sonarr-update` | batch/periodic | Daily version check (if enabled) |
| `sonarr-restore` | batch/parameterized | On-demand restore (if enabled) |

### Lidarr Pack

| Job | Type | Description |
|-----|------|-------------|
| `lidarr` | service | Main Lidarr service |
| `lidarr-backup` | batch/periodic | Daily backup (if enabled) |
| `lidarr-update` | batch/periodic | Daily version check (if enabled) |
| `lidarr-restore` | batch/parameterized | On-demand restore (if enabled) |

### Prowlarr Pack

| Job | Type | Description |
|-----|------|-------------|
| `prowlarr` | service | Main Prowlarr service |
| `prowlarr-backup` | batch/periodic | Daily backup (if enabled) |
| `prowlarr-update` | batch/periodic | Daily version check (if enabled) |
| `prowlarr-restore` | batch/parameterized | On-demand restore (if enabled) |

### Overseerr Pack

| Job | Type | Description |
|-----|------|-------------|
| `overseerr` | service | Main Overseerr service |
| `overseerr-backup` | batch/periodic | Daily backup (if enabled) |
| `overseerr-update` | batch/periodic | Daily version check (if enabled) |
| `overseerr-restore` | batch/parameterized | On-demand restore (if enabled) |

### Tautulli Pack

| Job | Type | Description |
|-----|------|-------------|
| `tautulli` | service | Main Tautulli service |
| `tautulli-backup` | batch/periodic | Daily backup (if enabled) |
| `tautulli-update` | batch/periodic | Daily version check (if enabled) |
| `tautulli-restore` | batch/parameterized | On-demand restore (if enabled) |

### SABnzbd Pack

| Job | Type | Description |
|-----|------|-------------|
| `sabnzbd` | service | Main SABnzbd service |
| `sabnzbd-backup` | batch/periodic | Daily backup (if enabled) |
| `sabnzbd-update` | batch/periodic | Daily version check (if enabled) |
| `sabnzbd-restore` | batch/parameterized | On-demand restore (if enabled) |

## Automatic Updates

Each pack includes an optional update job that periodically checks for new container versions and stores the latest version in a Nomad variable. This allows the main service job to reference `{{ with nomadVar }}` for automated updates.

### How Updates Work

1. **Version Check**: The update job runs on a configurable schedule (default: 3am daily)
2. **Docker Hub Query**: Queries the Docker Hub API for the latest stable container tag
3. **Nomad Variable Update**: Stores the version in `nomad/jobs/{service}` with key `version`
4. **Automatic Restart**: Each service template includes `DOCKER_IMAGE_VERSION` which reads from the Nomad variable. When the version changes, the rendered template changes, triggering Nomad to restart the service and pull the new container image

### Version Detection

The update jobs detect the latest stable version by querying Docker Hub and filtering for semantic version tags:

| Service | Image | Version Pattern | Example |
|---------|-------|-----------------|---------|
| Plex | Official Plex API | N/A | Uses plex.tv API directly |
| Jellyfin | linuxserver/jellyfin | `X.X.X` | `10.10.3` |
| Radarr | linuxserver/radarr | `X.X.X` | `6.0.4` |
| Sonarr | linuxserver/sonarr | `X.X.X.X` | `4.0.11.2680` |
| Lidarr | linuxserver/lidarr | `X.X.X.X` | `2.7.1.4417` |
| Prowlarr | linuxserver/prowlarr | `X.X.X.X` | `1.28.2.4885` |
| Overseerr | linuxserver/overseerr | `X.X.X` | `1.34.1` |
| Tautulli | linuxserver/tautulli | `X.X.X` | `2.15.0` |
| SABnzbd | linuxserver/sabnzbd | `X.X.X` | `4.4.1` |

**Note:** Plex uses the official Plex API at `plex.tv` to get the latest version, not the linuxserver container image.

### How Automatic Restarts Work

All service templates include a `DOCKER_IMAGE_VERSION` environment variable that reads from the Nomad variable:

```hcl
template {
  data = <<EOH
DOCKER_IMAGE_VERSION={{- with nomadVar "nomad/jobs/radarr" -}}{{ .version }}{{- end }}
EOH
  destination = "local/env_vars"
  env         = true
}
```

When the update job writes a new version to the Nomad variable, the rendered template changes. Nomad detects this change and restarts the task, which pulls the latest container image. The services use the `:latest` tag by default, so the version variable acts as a trigger for the restart rather than specifying the exact image tag.

### Checking Current Version

```bash
# View the stored version for a service
nomad var get nomad/jobs/radarr

# Manually trigger an update check
nomad job periodic force radarr-update
```

### Disabling Updates

```bash
nomad-pack run radarr --registry=mediaserver -var enable_update=false
```

## Backup and Restore

### What Gets Backed Up

- **Plex**: `Plug-in Support/Databases/*`, `Preferences.xml`
- **Jellyfin**: `data/*`, `config/*`
- **Radarr**: `radarr.db`, `config.xml`, `Backups/*`
- **Sonarr**: `sonarr.db`, `config.xml`, `Backups/*`
- **Lidarr**: `lidarr.db`, `config.xml`, `Backups/*`
- **Prowlarr**: `prowlarr.db`, `config.xml`, `Backups/*`
- **Overseerr**: `db/db.sqlite3`, `settings.json`
- **Tautulli**: `tautulli.db`, `config.ini`, `backups/*`
- **SABnzbd**: `sabnzbd.ini`, `sabnzbd.db`, `admin/*`

Backups are stored in the backup CSI volume at `/{service}/YYYY-MM-DD/`.

### Manual Backup

Backups run automatically at 2am. To trigger manually:

```bash
nomad job periodic force plex-backup
```

### Restore from Backup

Restore jobs are designed to be **ephemeral** - created only when needed and removed after completion. The recommended workflow using Ansible:

```bash
# Deploy and restore from latest backup
ansible-playbook -i inventory.ini playbooks/deploy-media-server.yml -e restore_from_backup=true

# Deploy and restore from specific date
ansible-playbook -i inventory.ini playbooks/deploy-arr-stack.yml -e restore_from_backup=true -e backup_date=2025-01-15
```

The Ansible workflow:
1. Deploys the pack with `enable_restore=true` (creates restore job only)
2. Dispatches the restore job
3. Waits for completion
4. Redeploys with `enable_restore=false` (removes restore job, starts service)

**Manual restore workflow:**

```bash
# 1. Deploy restore job only
nomad-pack run radarr --registry=mediaserver \
  -var enable_backup=false \
  -var enable_update=false \
  -var enable_restore=true

# 2. Dispatch restore
nomad job dispatch radarr-restore
# Or from specific date:
nomad job dispatch -meta backup_date=2025-01-15 radarr-restore

# 3. Wait for completion, then deploy normally (removes restore job)
nomad-pack run radarr --registry=mediaserver \
  -var enable_restore=false
```

**Available restore jobs:**
- `plex-restore`, `jellyfin-restore`
- `radarr-restore`, `sonarr-restore`, `lidarr-restore`, `prowlarr-restore`
- `overseerr-restore`, `tautulli-restore`, `sabnzbd-restore`

See [nomad-mediaserver-infra](https://github.com/brent-holden/nomad-mediaserver-infra) for the Ansible playbooks that handle this workflow automatically.

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

## SABnzbd Setup

SABnzbd is a Usenet download client that integrates with Radarr, Sonarr, and Lidarr.

### Initial Configuration

1. Access SABnzbd at `http://your-server:8080`
2. Complete the setup wizard
3. Configure your Usenet provider (Config → Servers)
4. Set up categories for automatic sorting (see below)

### Category Configuration

Configure categories in SABnzbd (Config → Categories) to sort downloads by type:

| Category | Folder | Used By |
|----------|--------|---------|
| `movies` | `/media/downloads/complete/movies` | Radarr |
| `tv` | `/media/downloads/complete/tv` | Sonarr |
| `music` | `/media/downloads/complete/music` | Lidarr |

### Connecting to *arr Apps

In each *arr app (Settings → Download Clients → Add → SABnzbd):

| Setting | Value |
|---------|-------|
| Host | `192.168.0.10` |
| Port | `8080` |
| API Key | Found in SABnzbd Config → General → API Key |
| Category | `movies` / `tv` / `music` (matching the *arr app) |

## *Arr Stack Setup

The *arr apps (Radarr, Sonarr, Lidarr, Prowlarr) work together with SABnzbd as an automated media management stack.

### Recommended Deployment Order

1. **SABnzbd** - Download client (configure Usenet servers)
2. **Prowlarr** - Indexer manager (configure indexers)
3. **Radarr** - Movie management (connect to Prowlarr + SABnzbd)
4. **Sonarr** - TV series management (connect to Prowlarr + SABnzbd)
5. **Lidarr** - Music management (connect to Prowlarr + SABnzbd)
6. **Overseerr** - Request management (connect to Plex + Radarr/Sonarr)
7. **Tautulli** - Plex monitoring (connect to Plex)

### Service Connections

After deployment, configure the services to communicate:

| Service | Connects To | Configuration Path |
|---------|-------------|-------------------|
| SABnzbd | Usenet providers | Config → Servers |
| Prowlarr | Radarr, Sonarr, Lidarr | Settings → Apps |
| Radarr | Prowlarr, SABnzbd | Settings → Indexers, Settings → Download Clients |
| Sonarr | Prowlarr, SABnzbd | Settings → Indexers, Settings → Download Clients |
| Lidarr | Prowlarr, SABnzbd | Settings → Indexers, Settings → Download Clients |
| Overseerr | Plex, Radarr, Sonarr | Settings → Plex, Settings → Radarr/Sonarr |
| Tautulli | Plex | Settings → Plex Media Server |

### Media Path Configuration

All services mount the media volume at `/media`. Configure paths as:

| Service | Root/Complete Folder | Incomplete Folder |
|---------|---------------------|-------------------|
| SABnzbd | `/media/downloads/complete` | `/media/downloads/incomplete` |
| Radarr | `/media/movies` | N/A |
| Sonarr | `/media/tv` | N/A |
| Lidarr | `/media/music` | N/A |

**Download Client Paths in *arr Apps:**

| Service | Download Path Setting |
|---------|----------------------|
| Radarr | `/media/downloads/complete/movies` |
| Sonarr | `/media/downloads/complete/tv` |
| Lidarr | `/media/downloads/complete/music` |

### API Keys

Each *arr app generates an API key on first run. Find it at:
- **Settings → General → Security → API Key**

You'll need these API keys when connecting services (e.g., adding Radarr to Prowlarr or Overseerr).

## Deploying the Full Stack

Deploy all services for a complete media automation setup:

```bash
# Add the registry
nomad-pack registry add mediaserver github.com/brent-holden/nomad-mediaserver-packs

# Deploy media server (choose one)
nomad-pack run plex --registry=mediaserver --var enable_restore=true
# or
nomad-pack run jellyfin --registry=mediaserver

# Deploy indexer manager
nomad-pack run prowlarr --registry=mediaserver

# Deploy media managers
nomad-pack run radarr --registry=mediaserver
nomad-pack run sonarr --registry=mediaserver
nomad-pack run lidarr --registry=mediaserver

# Deploy download client
nomad-pack run sabnzbd --registry=mediaserver

# Deploy request management and monitoring
nomad-pack run overseerr --registry=mediaserver
nomad-pack run tautulli --registry=mediaserver
```

**Note:** Each pack requires its corresponding host volume. Create volumes before deploying (see [Creating Host Volumes Manually](#creating-host-volumes-manually)).

## Destroying Deployments

```bash
# Destroy individual packs
nomad-pack destroy plex --registry=mediaserver
nomad-pack destroy jellyfin --registry=mediaserver
nomad-pack destroy radarr --registry=mediaserver
nomad-pack destroy sonarr --registry=mediaserver
nomad-pack destroy lidarr --registry=mediaserver
nomad-pack destroy prowlarr --registry=mediaserver
nomad-pack destroy overseerr --registry=mediaserver
nomad-pack destroy tautulli --registry=mediaserver
nomad-pack destroy sabnzbd --registry=mediaserver
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
nomad alloc logs -job plex-backup
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
- [nomad-csi-cifs](https://github.com/brent-holden/nomad-csi-cifs) - Standalone CSI CIFS/SMB plugin deployment and volume configurations

## License

MIT
