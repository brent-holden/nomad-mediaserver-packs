# Tautulli Pack

This pack deploys [Tautulli](https://tautulli.com/) to Nomad, with optional backup and version update jobs.

Tautulli is a monitoring and tracking tool for Plex Media Server. It provides detailed statistics about your Plex server usage, including who watched what, when, and how.

## Prerequisites

1. **Host Volumes** - Dynamic host volume (created automatically with Nomad 1.10+):
   - `tautulli-config` - Persistent configuration storage

2. **CSI Volumes** - Configure storage:
   - `backup-drive` - Backup storage (if `enable_backup=true`)

## Usage

```bash
nomad-pack run tautulli --registry=mediaserver
```

## Jobs Created

| Job | Description | Controlled By |
|-----|-------------|---------------|
| `tautulli` | Main Tautulli service | Always created |
| `tautulli-backup` | Periodic backup of Tautulli config | `enable_backup` |
| `tautulli-update` | Periodic version check | `enable_update` |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `tautulli_uid` | UID for Tautulli process (PUID) | `1000` |
| `tautulli_gid` | GID for Tautulli process (PGID) | `1000` |
| `port` | Tautulli web interface port | `8181` |

## Access

After deployment, access Tautulli at: `http://<nomad-client-ip>:8181`
