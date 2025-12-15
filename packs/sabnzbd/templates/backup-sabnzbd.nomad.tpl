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

    volume "sabnzbd-config" {
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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup-sabnzbd.sh"]
      }

      volume_mount {
        volume      = "sabnzbd-config"
        destination = "/sabnzbd-config"
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

echo "Starting SABnzbd backup job..."

# Install rsync
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Source files (SABnzbd stores important data here)
SABNZBD_INI="/sabnzbd-config/sabnzbd.ini"
SABNZBD_DB="/sabnzbd-config/sabnzbd.db"
SABNZBD_HISTORY="/sabnzbd-config/history.db"
SABNZBD_ADMIN="/sabnzbd-config/admin"

# Destination directory
BACKUP_DIR="/backups/sabnzbd"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

# Create backup directory structure
echo "Creating backup directory: $BACKUP_DEST"
mkdir -p "$BACKUP_DEST"

# Backup config file
if [ -f "$SABNZBD_INI" ]; then
    echo "Backing up sabnzbd.ini..."
    cp "$SABNZBD_INI" "$BACKUP_DEST/"
    echo "Config backup complete."
else
    echo "Warning: sabnzbd.ini not found at $SABNZBD_INI"
fi

# Backup database files
if [ -f "$SABNZBD_DB" ]; then
    echo "Backing up sabnzbd.db..."
    cp "$SABNZBD_DB" "$BACKUP_DEST/"
    echo "Database backup complete."
else
    echo "Warning: sabnzbd.db not found at $SABNZBD_DB"
fi

if [ -f "$SABNZBD_HISTORY" ]; then
    echo "Backing up history.db..."
    cp "$SABNZBD_HISTORY" "$BACKUP_DEST/"
    echo "History backup complete."
else
    echo "Note: history.db not found at $SABNZBD_HISTORY (may not exist yet)"
fi

# Backup admin directory (contains queue and history)
if [ -d "$SABNZBD_ADMIN" ]; then
    echo "Backing up admin directory..."
    rsync -av --progress "$SABNZBD_ADMIN/" "$BACKUP_DEST/admin/"
    echo "Admin directory backup complete."
else
    echo "Warning: admin directory not found at $SABNZBD_ADMIN"
fi

# Clean up old backups (keep last N days)
echo "Cleaning up old backups (keeping last [[ var "backup_retention_days" . ]] days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ var "backup_retention_days" . ]] -exec rm -rf {} \; 2>/dev/null || true

# Show backup size
echo "Backup complete. Size:"
du -sh "$BACKUP_DEST"

echo "Successfully backed up SABnzbd to $BACKUP_DEST"
EOF
        destination = "local/backup-sabnzbd.sh"
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
