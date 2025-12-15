# Prowlarr Pack

This pack deploys [Prowlarr](https://prowlarr.com/) to Nomad, with optional backup and version update jobs.

Prowlarr is an indexer manager for Sonarr, Radarr, Lidarr, Readarr, and other apps. It integrates with your download clients and manages your indexers, supporting both Usenet and BitTorrent.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `prowlarr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Usage

```bash
nomad-pack run prowlarr --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `prowlarr` | Main Prowlarr service | Always created |
| `prowlarr-backup` | Periodic backup of Prowlarr config | `enable_backup` |
| `prowlarr-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `prowlarr_uid` | UID for Prowlarr process (PUID) | `1000` |
| `prowlarr_gid` | GID for Prowlarr process (PGID) | `1000` |
| `port` | Prowlarr web interface port | `9696` |

## Access

After deployment, access Prowlarr at: `http://<nomad-client-ip>:9696`
