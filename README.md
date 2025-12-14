# Nomad Mediaserver Packs

A Nomad Pack registry for deploying media server applications to HashiCorp Nomad.

## Available Packs

| Pack | Description |
|------|-------------|
| `plex` | Plex Media Server with optional GPU transcoding, backup, and update jobs |
| `jellyfin` | Jellyfin Media Server with optional GPU transcoding, backup, and update jobs |

Each pack includes:
- **Main service** - The media server itself
- **Backup job** - Periodic backup of configuration (enabled by default)
- **Update job** - Periodic version check (enabled by default)

## Prerequisites

- [Nomad](https://developer.hashicorp.com/nomad/install) cluster running
- [Nomad Pack](https://developer.hashicorp.com/nomad/docs/tools/nomad-pack) installed (v0.1.0+ with v2 template parser)
- [Host volumes](#host-volumes-required) configured for application data
- [CSI volumes](#csi-volumes) configured for media storage (SMB/CIFS recommended)

## Volume Setup

Before deploying packs, you must configure both host volumes (for local configuration storage) and CSI volumes (for shared media storage).

### Host Volumes (Required)

Host volumes provide persistent local storage for application configuration. These must be configured on each Nomad client that will run the media server.

#### 1. Create the directories

**For Plex:**
```bash
sudo mkdir -p /opt/nomad/volumes/plex-config
sudo mkdir -p /opt/nomad/volumes/plex-transcode
sudo chown -R 1002:1001 /opt/nomad/volumes/plex-config
sudo chown -R 1002:1001 /opt/nomad/volumes/plex-transcode
```

**For Jellyfin:**
```bash
sudo mkdir -p /opt/nomad/volumes/jellyfin-config
sudo mkdir -p /opt/nomad/volumes/jellyfin-cache
sudo chown -R 1002:1001 /opt/nomad/volumes/jellyfin-config
sudo chown -R 1002:1001 /opt/nomad/volumes/jellyfin-cache
```

#### 2. Configure Nomad client

Add host volumes to your Nomad client configuration (e.g., `/etc/nomad.d/client.hcl`):

**For Plex:**
```hcl
client {
  host_volume "plex-config" {
    path      = "/opt/nomad/volumes/plex-config"
    read_only = false
  }

  host_volume "plex-transcode" {
    path      = "/opt/nomad/volumes/plex-transcode"
    read_only = false
  }
}
```

**For Jellyfin:**
```hcl
client {
  host_volume "jellyfin-config" {
    path      = "/opt/nomad/volumes/jellyfin-config"
    read_only = false
  }

  host_volume "jellyfin-cache" {
    path      = "/opt/nomad/volumes/jellyfin-cache"
    read_only = false
  }
}
```

See `examples/nomad-client-volumes.hcl` for a complete example.

#### 3. Restart Nomad client

```bash
sudo systemctl restart nomad
```

#### Host Volume Summary

| Pack | Volume | Default Name | Purpose |
|------|--------|--------------|---------|
| Plex | Config | `plex-config` | Plex configuration, database, and metadata |
| Plex | Transcode | `plex-transcode` | Temporary transcoding files |
| Jellyfin | Config | `jellyfin-config` | Jellyfin configuration, database, and metadata |
| Jellyfin | Cache | `jellyfin-cache` | Cache and transcoding files |

### CSI Volumes

These packs expect CSI volumes for shared storage. A CIFS/SMB CSI plugin is recommended for NAS-based media libraries.

#### Option A: Deploy CSI volumes with the pack

Set `deploy_csi_volumes=true` when running the pack:

```bash
nomad-pack run plex --registry=mediaserver \
  -var deploy_csi_volumes=true \
  -var csi_volume_password=your-password
```

#### Option B: Register CSI volumes manually

1. **Install a CSI plugin** - See [nomad-media-infra](https://github.com/brent-holden/nomad-media-infra) for complete CSI setup including:
   - CSI controller and node plugin job specifications
   - Ansible playbooks for automated deployment
   - Volume registration templates

2. **Register CSI volumes:**
   ```bash
   # Edit examples/media-drive-volume.hcl with your fileserver details
   nomad volume register examples/media-drive-volume.hcl

   # If using backups, also register the backup volume
   nomad volume register examples/backup-drive-volume.hcl
   ```

   **Important:** For CIFS/SMB backup volumes, include `cache=none` and `nobrl` in the mount flags to ensure rsync operations work correctly:
   ```hcl
   mount_flags = ["uid=1002", "gid=1001", "file_mode=0644", "dir_mode=0755", "vers=3.0", "cache=none", "nobrl"]
   ```

#### CSI Volume Summary

| Volume | Default Name | Purpose | Required |
|--------|--------------|---------|----------|
| Media | `media-drive` | Shared media library (NAS mount) | Yes |
| Backup | `backup-drive` | Backup storage location | Only if `enable_backup=true` |

## Install

### Add the Registry

```bash
nomad-pack registry add mediaserver https://github.com/brent-holden/nomad-mediaserver-packs
```

### Deploy

```bash
nomad-pack run plex --registry=mediaserver
```

or

```bash
nomad-pack run jellyfin --registry=mediaserver
```

By default, packs deploy with GPU transcoding, backup jobs, and update jobs enabled.

## Configuration

### Optional Flags

Disable features using `-var` flags:

```bash
# Disable GPU transcoding
nomad-pack run plex --registry=mediaserver -var gpu_transcoding=false

# Disable backup job
nomad-pack run plex --registry=mediaserver -var enable_backup=false

# Disable update job
nomad-pack run plex --registry=mediaserver -var enable_update=false

# Disable multiple features
nomad-pack run jellyfin --registry=mediaserver -var enable_backup=false -var enable_update=false

# Use a custom variables file
nomad-pack run plex --registry=mediaserver -f my-plex-vars.hcl
```

Each pack has configurable variables. View available variables:

```bash
nomad-pack info plex --registry=mediaserver
```

Generate a variables file:

```bash
nomad-pack generate var-file plex --registry=mediaserver > plex-vars.hcl
```

### Common Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `datacenters` | List of eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `timezone` | Timezone for schedules | `America/New_York` |

### Plex Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gpu_transcoding` | Enable GPU passthrough for hardware transcoding | `true` |
| `plex_uid` | UID for Plex user | `1002` |
| `plex_gid` | GID for Plex group | `1001` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `enable_backup` | Deploy backup job | `true` |
| `enable_update` | Deploy update job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` |
| `backup_retention_days` | Days to keep backups | `14` |

### Jellyfin Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gpu_transcoding` | Enable GPU passthrough for hardware transcoding | `true` |
| `jellyfin_uid` | UID for Jellyfin user | `1002` |
| `jellyfin_gid` | GID for Jellyfin group | `1001` |
| `cpu` | CPU allocation (MHz) | `16000` |
| `memory` | Memory allocation (MB) | `16384` |
| `enable_backup` | Deploy backup job | `true` |
| `enable_update` | Deploy update job | `true` |
| `backup_cron_schedule` | Backup schedule | `0 2 * * *` |
| `update_cron_schedule` | Update schedule | `0 3 * * *` |
| `backup_retention_days` | Days to keep backups | `14` |

### CSI Volume Variables

Optionally deploy CSI volumes as part of the pack (disabled by default):

| Variable | Description | Default |
|----------|-------------|---------|
| `deploy_csi_volumes` | Deploy CSI volumes for media and backup storage | `false` |
| `csi_plugin_id` | CSI plugin ID to use | `smb` |
| `csi_volume_username` | Username for CIFS/SMB authentication | `plex`/`jellyfin` |
| `csi_volume_password` | Password for CIFS/SMB authentication | `""` |
| `media_volume_source` | CIFS/SMB source path for media | `//10.100.0.1/media` |
| `backup_volume_source` | CIFS/SMB source path for backups | `//10.100.0.1/backups` |

Example deploying with CSI volumes:

```bash
nomad-pack run plex --registry=mediaserver \
  -var deploy_csi_volumes=true \
  -var csi_volume_password=secret
```

## Application Setup

### Plex

1. Set up Nomad variables for Plex claim token:
   ```bash
   nomad var put nomad/jobs/plex claim_token="<YOUR-CLAIM-TOKEN>" version="latest"
   ```
   Get your claim token from [plex.tv/claim](https://www.plex.tv/claim/).

2. (Optional) For GPU transcoding, ensure `/dev/dri` exists on the host.

### Jellyfin

1. (Optional) For GPU transcoding (enabled by default), ensure `/dev/dri` exists on the host.

No additional setup required. Jellyfin will initialize on first run.

## Destroying Deployments

```bash
nomad-pack destroy plex --registry=mediaserver
nomad-pack destroy jellyfin --registry=mediaserver
```

## License

MIT
