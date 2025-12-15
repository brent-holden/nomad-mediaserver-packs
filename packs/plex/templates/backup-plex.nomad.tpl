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

    volume "plex-config" {
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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup-plex.sh"]
      }

      volume_mount {
        volume      = "plex-config"
        destination = "/plex-config"
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

echo "Starting Plex backup job..."

# Install rsync
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Source directories (Plex stores important data here)
PLEX_DB_DIR="/plex-config/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
PLEX_PREFS="/plex-config/Library/Application Support/Plex Media Server/Preferences.xml"

# Destination directory
BACKUP_DIR="/backups/plex"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

# Create backup directory structure
echo "Creating backup directory: $BACKUP_DEST"
mkdir -p "$BACKUP_DEST/Databases"

# Backup database files (includes Plex's own backups)
if [ -d "$PLEX_DB_DIR" ]; then
    echo "Backing up Plex databases..."
    rsync -av --progress "$PLEX_DB_DIR/" "$BACKUP_DEST/Databases/"
    echo "Database backup complete."
else
    echo "Warning: Plex database directory not found at $PLEX_DB_DIR"
fi

# Backup preferences file
if [ -f "$PLEX_PREFS" ]; then
    echo "Backing up Preferences.xml..."
    cp "$PLEX_PREFS" "$BACKUP_DEST/"
    echo "Preferences backup complete."
else
    echo "Warning: Preferences.xml not found at $PLEX_PREFS"
fi

# Clean up old backups (keep last N days)
echo "Cleaning up old backups (keeping last [[ var "backup_retention_days" . ]] days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ var "backup_retention_days" . ]] -exec rm -rf {} \; 2>/dev/null || true

# Show backup size
echo "Backup complete. Size:"
du -sh "$BACKUP_DEST"

echo "Successfully backed up Plex to $BACKUP_DEST"
EOF
        destination = "local/backup-plex.sh"
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
