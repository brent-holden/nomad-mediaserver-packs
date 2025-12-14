job "[[ .backup_jellyfin.job_name ]]" {
  region      = "[[ .backup_jellyfin.region ]]"
  datacenters = [[ .backup_jellyfin.datacenters | toJson ]]
  namespace   = "[[ .backup_jellyfin.namespace ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ .backup_jellyfin.cron_schedule ]]"]
    time_zone        = "[[ .backup_jellyfin.timezone ]]"
    prohibit_overlap = true
  }

  group "backup" {
    count = 1

    restart {
      attempts = 2
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    volume "jellyfin-config" {
      type      = "host"
      source    = "[[ .backup_jellyfin.config_volume_name ]]"
      read_only = true
    }

    volume "backup-drive" {
      type            = "csi"
      source          = "[[ .backup_jellyfin.backup_volume_name ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    task "backup" {
      driver = "podman"

      config {
        image = "[[ .backup_jellyfin.image ]]"
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup-jellyfin.sh"]
      }

      volume_mount {
        volume      = "jellyfin-config"
        destination = "/jellyfin-config"
        read_only   = true
      }

      volume_mount {
        volume      = "backup-drive"
        destination = "/backups"
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting Jellyfin backup job..."

# Install rsync
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Source directories (Jellyfin stores important data here)
JELLYFIN_DATA_DIR="/jellyfin-config/data"
JELLYFIN_CONFIG_DIR="/jellyfin-config/config"

# Destination directory
BACKUP_DIR="/backups/jellyfin"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

# Create backup directory structure
echo "Creating backup directory: $BACKUP_DEST"
mkdir -p "$BACKUP_DEST/data" "$BACKUP_DEST/config"

# Backup data directory (contains jellyfin.db and library data)
if [ -d "$JELLYFIN_DATA_DIR" ]; then
    echo "Backing up Jellyfin data directory..."
    rsync -av --progress "$JELLYFIN_DATA_DIR/" "$BACKUP_DEST/data/"
    echo "Data backup complete."
else
    echo "Warning: Jellyfin data directory not found at $JELLYFIN_DATA_DIR"
fi

# Backup config directory (contains configuration files)
if [ -d "$JELLYFIN_CONFIG_DIR" ]; then
    echo "Backing up Jellyfin config directory..."
    rsync -av --progress "$JELLYFIN_CONFIG_DIR/" "$BACKUP_DEST/config/"
    echo "Config backup complete."
else
    echo "Warning: Jellyfin config directory not found at $JELLYFIN_CONFIG_DIR"
fi

# Clean up old backups (keep last N days)
echo "Cleaning up old backups (keeping last [[ .backup_jellyfin.retention_days ]] days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ .backup_jellyfin.retention_days ]] -exec rm -rf {} \; 2>/dev/null || true

# Show backup size
echo "Backup complete. Size:"
du -sh "$BACKUP_DEST"

echo "Successfully backed up Jellyfin to $BACKUP_DEST"
EOF
        destination = "local/backup-jellyfin.sh"
        perms       = "0755"
      }

      resources {
        cpu    = [[ .backup_jellyfin.cpu ]]
        memory = [[ .backup_jellyfin.memory ]]
      }
    }
  }
}
