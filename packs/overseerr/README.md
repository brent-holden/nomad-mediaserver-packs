# Overseerr Pack

This pack deploys [Overseerr](https://overseerr.dev/) to Nomad, with optional backup and version update jobs.

Overseerr is a request management and media discovery tool for your Plex ecosystem. It integrates with Plex, Radarr, and Sonarr to provide a seamless interface for users to request movies and TV shows.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `overseerr-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Usage

```bash
nomad-pack run overseerr --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `overseerr` | Main Overseerr service | Always created |
| `overseerr-backup` | Periodic backup of Overseerr config | `enable_backup` |
| `overseerr-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `overseerr_uid` | UID for Overseerr process (PUID) | `1000` |
| `overseerr_gid` | GID for Overseerr process (PGID) | `1000` |
| `port` | Overseerr web interface port | `5055` |

## Access

After deployment, access Overseerr at: `http://<nomad-client-ip>:5055`
