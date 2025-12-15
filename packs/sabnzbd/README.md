# SABnzbd Pack

This pack deploys [SABnzbd](https://sabnzbd.org/) to Nomad, with optional backup and version update jobs.

SABnzbd is a free and easy binary newsreader. It simplifies the process of downloading from Usenet by automating the download, verification, repair, extraction, and clean-up of files.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `sabnzbd-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `media-drive` - Downloads directory (mounted at `/media`)
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Download Path Configuration

SABnzbd mounts the media volume at `/media`. Configure your download paths as:
- **Completed Downloads**: `/media/downloads/complete`
- **Incomplete Downloads**: `/media/downloads/incomplete`

This allows the *arr apps (Radarr, Sonarr, Lidarr) to use hardlinks when importing, since they share the same volume.

## Usage

```bash
nomad-pack run sabnzbd --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `sabnzbd` | Main SABnzbd service | Always created |
| `sabnzbd-backup` | Periodic backup of SABnzbd config | `enable_backup` |
| `sabnzbd-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `sabnzbd_uid` | UID for SABnzbd process (PUID) | `1000` |
| `sabnzbd_gid` | GID for SABnzbd process (PGID) | `1000` |
| `port` | SABnzbd web interface port | `8080` |
| `cpu` | CPU allocation (MHz) | `1000` |
| `memory` | Memory allocation (MB) | `2048` |

## Access

After deployment, access SABnzbd at: `http://<nomad-client-ip>:8080`

## Integration with *arr Apps

1. **In SABnzbd**: Configure categories for movies, tv, and music
2. **In Radarr/Sonarr/Lidarr**: Add SABnzbd as a download client
   - Settings → Download Clients → Add → SABnzbd
   - Host: `192.168.0.10`
   - Port: `8080`
   - API Key: Found in SABnzbd Config → General → API Key
