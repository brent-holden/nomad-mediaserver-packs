# Sonarr Pack

This pack deploys [Sonarr](https://sonarr.tv/) to Nomad, with optional backup and version update jobs.

Sonarr is a TV series collection manager for Usenet and BitTorrent users. It monitors multiple RSS feeds for new episodes of your favorite shows and interfaces with clients and indexers to grab, sort, and rename them.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `sonarr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `media-drive` - Your media library (TV shows and downloads)
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Media Volume Structure

The `media-drive` CSI volume is mounted at `/media`. Configure Sonarr to use:
- **Root Folder**: `/media/tv`
- **Download Client Path**: `/media/downloads/complete/tv`

## Usage

```bash
nomad-pack run sonarr --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `sonarr` | Main Sonarr service | Always created |
| `sonarr-backup` | Periodic backup of Sonarr config | `enable_backup` |
| `sonarr-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `sonarr_uid` | UID for Sonarr process (PUID) | `1000` |
| `sonarr_gid` | GID for Sonarr process (PGID) | `1000` |
| `port` | Sonarr web interface port | `8989` |

## Access

After deployment, access Sonarr at: `http://<nomad-client-ip>:8989`
