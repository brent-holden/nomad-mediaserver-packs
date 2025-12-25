# Seerr Pack

This pack deploys [Seerr](https://seerr.dev/) to Nomad, with optional backup and version update jobs.

Seerr is a request management and media discovery tool for Jellyfin, Plex, and Emby. It integrates with Radarr and Sonarr to provide a seamless interface for users to request movies and TV shows.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `seerr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Usage

```bash
nomad-pack run seerr --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `seerr` | Main Seerr service | Always created |
| `seerr-backup` | Periodic backup of Seerr config | `enable_backup` |
| `seerr-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `seerr_uid` | UID for Seerr process | `1002` |
| `seerr_gid` | GID for Seerr process | `1001` |
| `port` | Seerr web interface port | `5055` |

## Access

After deployment, access Seerr at: `http://<nomad-client-ip>:5055`
