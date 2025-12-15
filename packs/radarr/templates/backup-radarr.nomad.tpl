[[- if var "enable_backup" . ]]
job "[[ var "job_name" . ]]-backup" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ var "backup_cron_schedule" . ]]"]
    time_zone        = "[[ var "timezone" . ]]"
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

    volume "radarr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
      read_only       = true
    }

    volume "backup-drive" {
      type            = "csi"
      source          = "[[ var "backup_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    task "backup" {
      driver = "podman"

      config {
        image = "docker.io/debian:bookworm-slim"
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup-radarr.sh"]
      }

      volume_mount {
        volume      = "radarr-config"
        destination = "/radarr-config"
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

echo "Starting Radarr backup job..."

# Install rsync
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Source directories (Radarr stores important data here)
RADARR_DB="/radarr-config/radarr.db"
RADARR_CONFIG="/radarr-config/config.xml"
RADARR_BACKUPS="/radarr-config/Backups"

# Destination directory
BACKUP_DIR="/backups/radarr"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

# Create backup directory structure
echo "Creating backup directory: $BACKUP_DEST"
mkdir -p "$BACKUP_DEST"

# Backup database file
if [ -f "$RADARR_DB" ]; then
    echo "Backing up Radarr database..."
    cp "$RADARR_DB" "$BACKUP_DEST/"
    echo "Database backup complete."
else
    echo "Warning: Radarr database not found at $RADARR_DB"
fi

# Backup config file
if [ -f "$RADARR_CONFIG" ]; then
    echo "Backing up config.xml..."
    cp "$RADARR_CONFIG" "$BACKUP_DEST/"
    echo "Config backup complete."
else
    echo "Warning: config.xml not found at $RADARR_CONFIG"
fi

# Backup Radarr's own backup files
if [ -d "$RADARR_BACKUPS" ]; then
    echo "Backing up Radarr internal backups..."
    rsync -av --progress "$RADARR_BACKUPS/" "$BACKUP_DEST/Backups/"
    echo "Internal backups complete."
else
    echo "Warning: Radarr Backups directory not found at $RADARR_BACKUPS"
fi

# Clean up old backups (keep last N days)
echo "Cleaning up old backups (keeping last [[ var "backup_retention_days" . ]] days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ var "backup_retention_days" . ]] -exec rm -rf {} \; 2>/dev/null || true

# Show backup size
echo "Backup complete. Size:"
du -sh "$BACKUP_DEST"

echo "Successfully backed up Radarr to $BACKUP_DEST"
EOF
        destination = "local/backup-radarr.sh"
        perms       = "0755"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
[[- end ]]
