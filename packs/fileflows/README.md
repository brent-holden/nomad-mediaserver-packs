# FileFlows Pack

This pack deploys [FileFlows](https://fileflows.com) to Nomad, with optional backup, restore, and version update jobs. FileFlows is an automated file processing application that uses visual workflow pipelines to transcode, convert, and organize media files.

## Prerequisites

1. **Nomad Variables** - Set the FileFlows version:
   ```bash
   nomad var put nomad/jobs/fileflows version="latest"
   ```

2. **Host Volumes** - Configure on your Nomad clients:
   - `fileflows-config` - Persistent configuration and database storage

3. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library
   - `backup-drive` - Backup storage (if `enable_backup=true`)

4. **GPU (Optional but recommended)** - For hardware transcoding with Intel Arc B580:
   - Ensure `/dev/dri/card1` and `/dev/dri/renderD129` exist on the host
   - See the Unmanic pack's [GPU Driver Setup](../unmanic/README.md#gpu-driver-setup) for Intel media driver build instructions

## Usage

```bash
# Deploy with defaults (GPU enabled, backup enabled, update enabled)
nomad-pack run packs/fileflows

# Deploy without GPU transcoding
nomad-pack run packs/fileflows -var gpu_transcoding=false

# Deploy without backup job
nomad-pack run packs/fileflows -var enable_backup=false

# Deploy with custom resources
nomad-pack run packs/fileflows -var cpu=8000 -var memory=8192
```

## Jobs Created

This pack creates up to 4 Nomad jobs:

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `fileflows` | Main FileFlows service | Always created |
| `fileflows-backup` | Periodic backup of config, database, flows, and plugins | `enable_backup` |
| `fileflows-update` | Periodic version check from Docker Hub | `enable_update` |
| `fileflows-restore` | Parameterized restore job (dispatch manually) | `enable_restore` |

## Variables

### Service Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `fileflows` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `image` | Container image | `docker.io/revenz/fileflows:latest` |
| `gpu_transcoding` | Enable GPU passthrough and host driver mounts | `true` |
| `gpu_devices` | GPU device mappings (host:container) | `card1`, `renderD129` |
| `fileflows_uid` | UID for FileFlows user | `1002` |
| `fileflows_gid` | GID for FileFlows group | `1001` |
| `timezone` | Container timezone | `America/New_York` |
| `cpu` | CPU allocation (MHz) | `4000` |
| `memory` | Memory allocation (MB) | `4096` |
| `port` | FileFlows web UI port | `5000` |
| `media_volume_name` | CSI volume name | `media-drive` |
| `config_volume_name` | Config host volume | `fileflows-config` |
| `temp_path` | Host path for processing cache | `/tmp/fileflows` |
| `register_consul_service` | Register with Consul | `true` |
| `consul_service_name` | Consul service name | `fileflows` |

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
| `nomad_variable_path` | Nomad variable path | `nomad/jobs/fileflows` |

### Restore Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_restore` | Enable restore job | `false` |

## Temporary Processing Directory

FileFlows writes large temporary files during transcoding. The `temp_path` variable controls where these are stored on the host. For best performance, point this to fast storage (SSD/NVMe):

```bash
nomad-pack run packs/fileflows -var temp_path=/ssd/fileflows-temp
```

## Self-Healing

The Consul health check includes a `check_restart` policy: if the web UI fails 5 consecutive checks (~2.5 minutes of unresponsiveness), Nomad restarts the task automatically. This recovers the server from wedged states caused by CPU starvation during heavy transcoding (e.g. 4K VMAF quality comparisons), which would otherwise leave the UI unreachable until the processing finishes. Note that a restart kills any in-flight flows; FileFlows will re-queue them on startup.

## Access

After deployment, access FileFlows at: `http://<nomad-client-ip>:5000`
