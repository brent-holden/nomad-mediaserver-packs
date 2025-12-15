job "volumes-[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "batch"

  group "register-volumes" {
    count = 1

    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "register" {
      driver = "podman"

      config {
        image = "docker.io/curlimages/curl:latest"
        args  = ["/bin/sh", "/local/register-volumes.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

NOMAD_ADDR="${NOMAD_ADDR:-http://host.containers.internal:4646}"

echo "Registering volumes with Nomad at $NOMAD_ADDR..."

# Register plex-config dynamic host volume
echo "Creating dynamic host volume: [[ var "config_volume_name" . ]]"
cat > /tmp/config-volume.json << 'CONFIG_EOF'
{
  "ID": "[[ var "config_volume_name" . ]]",
  "Name": "[[ var "config_volume_name" . ]]",
  "Type": "host",
  "PluginID": "mkdir",
  "RequestedCapabilities": [
    {
      "AccessMode": "single-node-writer",
      "AttachmentMode": "file-system"
    }
  ],
  "Parameters": {
    "mode": "0755",
    "uid": "[[ var "plex_uid" . ]]",
    "gid": "[[ var "plex_gid" . ]]"
  }
}
CONFIG_EOF

curl -sf -X PUT "$NOMAD_ADDR/v1/volume/host/[[ var "config_volume_name" . ]]/create" \
  -H "Content-Type: application/json" \
  -d @/tmp/config-volume.json && echo " -> Success" || echo " -> Already exists or failed"

# Register plex-transcode dynamic host volume
echo "Creating dynamic host volume: [[ var "transcode_volume_name" . ]]"
cat > /tmp/transcode-volume.json << 'TRANSCODE_EOF'
{
  "ID": "[[ var "transcode_volume_name" . ]]",
  "Name": "[[ var "transcode_volume_name" . ]]",
  "Type": "host",
  "PluginID": "mkdir",
  "RequestedCapabilities": [
    {
      "AccessMode": "single-node-writer",
      "AttachmentMode": "file-system"
    }
  ],
  "Parameters": {
    "mode": "0755",
    "uid": "[[ var "plex_uid" . ]]",
    "gid": "[[ var "plex_gid" . ]]"
  }
}
TRANSCODE_EOF

curl -sf -X PUT "$NOMAD_ADDR/v1/volume/host/[[ var "transcode_volume_name" . ]]/create" \
  -H "Content-Type: application/json" \
  -d @/tmp/transcode-volume.json && echo " -> Success" || echo " -> Already exists or failed"

[[- if var "deploy_csi_volumes" . ]]
# Register media CSI volume
[[- if var "media_volume_source" . ]]
echo "Registering CSI volume: [[ var "media_volume_name" . ]]"
cat > /tmp/media-volume.json << 'MEDIA_EOF'
{
  "ID": "[[ var "media_volume_name" . ]]",
  "Name": "[[ var "media_volume_name" . ]]",
  "Type": "csi",
  "PluginID": "[[ var "csi_plugin_id" . ]]",
  "RequestedCapabilities": [
    {
      "AccessMode": "multi-node-multi-writer",
      "AttachmentMode": "file-system"
    }
  ],
  "MountOptions": {
    "FSType": "cifs",
    "MountFlags": ["uid=[[ var "plex_uid" . ]]", "gid=[[ var "plex_gid" . ]]", "file_mode=0644", "dir_mode=0755", "vers=3.0"]
  },
  "Secrets": {
    "username": "[[ var "csi_volume_username" . ]]",
    "password": "[[ var "csi_volume_password" . ]]"
  },
  "Context": {
    "source": "[[ var "media_volume_source" . ]]"
  }
}
MEDIA_EOF

curl -sf -X PUT "$NOMAD_ADDR/v1/volume/csi/[[ var "media_volume_name" . ]]/create" \
  -H "Content-Type: application/json" \
  -d @/tmp/media-volume.json && echo " -> Success" || {
    curl -sf -X PUT "$NOMAD_ADDR/v1/volume/csi/[[ var "media_volume_name" . ]]" \
      -H "Content-Type: application/json" \
      -d @/tmp/media-volume.json && echo " -> Success (updated)"
  }
[[- end ]]

# Register backup CSI volume
[[- if and (var "enable_backup" .) (var "backup_volume_source" .) ]]
echo "Registering CSI volume: [[ var "backup_volume_name" . ]]"
cat > /tmp/backup-volume.json << 'BACKUP_EOF'
{
  "ID": "[[ var "backup_volume_name" . ]]",
  "Name": "[[ var "backup_volume_name" . ]]",
  "Type": "csi",
  "PluginID": "[[ var "csi_plugin_id" . ]]",
  "RequestedCapabilities": [
    {
      "AccessMode": "multi-node-multi-writer",
      "AttachmentMode": "file-system"
    }
  ],
  "MountOptions": {
    "FSType": "cifs",
    "MountFlags": ["uid=[[ var "plex_uid" . ]]", "gid=[[ var "plex_gid" . ]]", "file_mode=0644", "dir_mode=0755", "vers=3.0", "cache=none", "nobrl"]
  },
  "Secrets": {
    "username": "[[ var "csi_volume_username" . ]]",
    "password": "[[ var "csi_volume_password" . ]]"
  },
  "Context": {
    "source": "[[ var "backup_volume_source" . ]]"
  }
}
BACKUP_EOF

curl -sf -X PUT "$NOMAD_ADDR/v1/volume/csi/[[ var "backup_volume_name" . ]]/create" \
  -H "Content-Type: application/json" \
  -d @/tmp/backup-volume.json && echo " -> Success" || {
    curl -sf -X PUT "$NOMAD_ADDR/v1/volume/csi/[[ var "backup_volume_name" . ]]" \
      -H "Content-Type: application/json" \
      -d @/tmp/backup-volume.json && echo " -> Success (updated)"
  }
[[- end ]]
[[- end ]]

echo "Volume registration complete!"
EOF
        destination = "local/register-volumes.sh"
        perms       = "0755"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
