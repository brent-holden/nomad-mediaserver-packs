# FileFlows Pack

[FileFlows](https://fileflows.com/) — video file processing pipeline running ffmpeg-based flows (AV1/HEVC optimization, audio conversion, etc.).

## Jobs

| Job | Type | Purpose |
|-----|------|---------|
| `fileflows` | service | FileFlows server + internal processing agent |
| `fileflows-update` | periodic (daily 3am) | Tracks the latest stable FileFlows version; optionally applies it |
| `fileflows-backup` | periodic (daily 2am) | Consistent SQLite snapshot + config/plugins backup |
| `fileflows-health` | periodic (every 4h) | Detects the "silently broken" failure modes (see below) |

## Image pinning — important

The service job runs a **pinned numeric image tag** (default `26.10`) with `force_pull = false`.
Never switch this to `:latest`: every restart would then silently upgrade FileFlows, and each
upgrade re-runs every enabled DockerMod install script — one failed mod (e.g. a package removed
from Ubuntu repos) blocks **all** file processing while the Nomad job stays green.

Upgrades are handled by `fileflows-update`:

- It records the newest stable tag and the previous one in the Nomad variable
  `nomad/jobs/fileflows` (`version`, `previous_version`).
- With `auto_apply_update = false` (default) it does **not** apply the upgrade — redeploy with
  `nomad pack deploy packs/fileflows fileflows -var image=docker.io/revenz/fileflows:<tag>`
  when you want it.
- With `auto_apply_update = true` it re-submits the running job spec with the new tag
  (recorded as a new Nomad job version, easy to roll back).

To roll back a bad upgrade:

```
nomad var get nomad/jobs/fileflows          # note previous_version
nomad pack deploy packs/fileflows fileflows -var image=docker.io/revenz/fileflows:<previous_version>
```

## Health checks

FileFlows has a catastrophic failure mode: if **any single** enabled DockerMod fails to install,
the agent rejects every file-processing request (`DockerMod 'X' not installed`) and nothing
processes — for as long as the Nomad job looks perfectly healthy. It also auto-disables
libraries after repeated failures. This happened in Nov 2026 (comskip + Neofetch mods) and
silently killed processing for months.

`fileflows-health` detects all three signatures:

1. `DockerMod '...' not installed` rejections in the live allocation logs (after the agent's
   last registration — a short burst during startup is normal)
2. Expected libraries (default `TV`, `Movies`) that have been auto-disabled
3. A stale queue: unprocessed backlog, nothing processing, no database activity for 48h

The job exits non-zero on failure, which is visible in `nomad status fileflows-health` and in
Nomad's `job_summary.failed` metric (this cluster's Prometheus scrapes Nomad, so it can drive a
Grafana alert). Set `health_webhook_url` to also POST failures to Gotify/Discord/etc.

## DockerMods — keep the enabled set minimal

Every enabled DockerMod is a single point of failure for all processing. Only enable mods that
flows actually use. Currently justified: FFmpeg FileFlows Edition, FFmpeg-BtbN (SVT-AV1-PSY),
ab-av1 (VMAF-targeted encoding used by the Optimize flows), ImageMagick (image flows), rar
(comic flows), oneVPL (QuickSync), YouTube Downloader. Removed as pure risk: comskip, Neofetch
(dropped from Ubuntu repos — can never install), dovi_tool, ExifTool, Git, htop, MKVToolNix,
nano, Node.js.

## Volumes

- `fileflows-config` (host volume, on the media node) → `/app/Data`
- `media-drive` (CSI) → `/media`
- `backup-drive` (CSI) → `/backups` (backup job only)
