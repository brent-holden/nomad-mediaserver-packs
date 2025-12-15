# Lidarr Pack

This pack deploys [Lidarr](https://lidarr.audio/) to Nomad, with optional backup and version update jobs.

Lidarr is a music collection manager for Usenet and BitTorrent users. It monitors multiple RSS feeds for new albums from your favorite artists and interfaces with clients and indexers to grab, sort, and rename them.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `lidarr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library (music and downloads)
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Media Volume Structure

The `media-drive` CSI volume is mounted at `/media`. Configure Lidarr to use:
- **Root Folder**: `/media/music`
- **Download Client Path**: `/media/downloads/complete/music`

## Usage

```bash
nomad-pack run lidarr --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `lidarr` | Main Lidarr service | Always created |
| `lidarr-backup` | Periodic backup of Lidarr config | `enable_backup` |
| `lidarr-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `lidarr_uid` | UID for Lidarr process (PUID) | `1000` |
| `lidarr_gid` | GID for Lidarr process (PGID) | `1000` |
| `port` | Lidarr web interface port | `8686` |

## Access

After deployment, access Lidarr at: `http://<nomad-client-ip>:8686`
