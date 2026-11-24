# FileFlows Pack

This pack deploys [FileFlows](https://fileflows.com) to Nomad, with optional backup, restore, and version update jobs. FileFlows is an automated file processing application that uses visual workflow pipelines to transcode, convert, and organize media files.

## Prerequisites

- **`media-drive` volume with `cache=none`** in its mount flags — the elrepo mainline
  kernel's CIFS page-cache writeback is broken (buffered writes >300MB fail with EFAULT
  and destroy files being replaced); direct writes bypass it. See
  `examples/media-drive-volume.hcl`.

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
| `memory` | Memory allocation (MB) | `16384` (two concurrent 4K VMAF encodes peak past 4GB) |
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

## Image Pinning — important

The service job runs a **pinned numeric image tag** (default `26.11`) with `force_pull = false`.
Never switch this to `:latest`: every restart would then silently upgrade FileFlows, and each
upgrade re-runs every enabled DockerMod install script — one failed mod (e.g. a package removed
from Ubuntu repos) blocks **all** file processing while the Nomad job stays green.

Upgrades are handled by `fileflows-update`:

- It records the newest stable tag and the previous one in the Nomad variable
  `nomad/jobs/fileflows` (`version`, `previous_version`).
- With `auto_apply_update = false` (default) it does **not** apply the upgrade — redeploy with
  `nomad-pack run packs/fileflows --name=fileflows -var image=docker.io/revenz/fileflows:<tag>`
  when you want it.
- With `auto_apply_update = true` it re-submits the running job spec with the new tag
  (recorded as a new Nomad job version, easy to roll back).

To roll back a bad upgrade:

```bash
nomad var get nomad/jobs/fileflows          # note previous_version
nomad-pack run packs/fileflows --name=fileflows -var image=docker.io/revenz/fileflows:<previous_version>
```

## Health Monitoring (fileflows-health)

FileFlows has a catastrophic failure mode: if **any single** enabled DockerMod fails to install,
the agent rejects every file-processing request (`DockerMod 'X' not installed`) and nothing
processes — for as long as the Nomad job looks perfectly healthy. It also auto-disables
libraries after repeated failures. This happened in Nov 2026 (comskip + Neofetch mods) and
silently killed processing for months.

`fileflows-health` (default schedule `0 3,7,11,15,19,23 * * *` — every 4h, staggered off the 2am backup / 3am update window) detects all three signatures:

1. `DockerMod '...' not installed` rejections in the live allocation logs (after the agent's
   last registration — a short burst during startup is normal)
2. Expected libraries (default `TV`, `Movies`) that have been auto-disabled
3. A stale queue: unprocessed backlog, nothing processing, no database activity for 48h

The job exits non-zero on failure, which is visible in `nomad status fileflows-health` and in
Nomad's `job_summary.failed` metric (Prometheus scrapes Nomad, so it can drive a Grafana alert).
Set `health_webhook_url` to also POST failures to Gotify/Discord/etc.

## DockerMods — keep the enabled set minimal

Every enabled DockerMod is a single point of failure for all processing. Only enable mods that
flows actually use. Currently justified: FFmpeg FileFlows Edition, FFmpeg-BtbN (SVT-AV1-PSY),
ab-av1 (VMAF-targeted encoding used by the Optimize flows), ImageMagick (image flows), rar
(comic flows), oneVPL (QuickSync), YouTube Downloader. Removed as pure risk: comskip, Neofetch
(dropped from Ubuntu repos — can never install), dovi_tool, ExifTool, Git, htop, MKVToolNix,
nano, Node.js.

## Backup layout

`fileflows-backup` takes a consistent SQLite snapshot (`sqlite3 .backup`) of
`Data/FileFlows.sqlite` and copies `server.config`, `Data/Config`, `Plugins` and `Templates`.
(The pre-26.x layout — `FileFlows.db`, `fileflows.config`, `Flows/`, `Libraries/` — no longer
exists; older versions of this job produced empty backups.)


## Access

After deployment, access FileFlows at: `http://<nomad-client-ip>:5000`
