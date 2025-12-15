[[- if var "enable_restore" . ]]
job "restore-[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "batch"

  # Parameterized job - must be dispatched manually
  parameterized {
    payload       = "forbidden"
    meta_required = []
    meta_optional = ["backup_date"]
  }

  group "restore" {
    count = 1

    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    volume "plex-config" {
      type   = "host"
      source = "[[ var "config_volume_name" . ]]"
    }

    volume "backup-drive" {
      type            = "csi"
      source          = "[[ var "backup_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
      read_only       = true
    }

    task "restore" {
      driver = "podman"

      config {
        image = "docker.io/debian:bookworm-slim"
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/restore-plex.sh"]
      }

      volume_mount {
        volume      = "plex-config"
        destination = "/plex-config"
      }

      volume_mount {
        volume      = "backup-drive"
        destination = "/backups"
        read_only   = true
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "=========================================="
echo "Plex Restore Job"
echo "=========================================="

# Install required tools
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Configuration
BACKUP_DIR="/backups/plex"
PLEX_CONFIG="/plex-config"
PLEX_MEDIA_SERVER="$PLEX_CONFIG/Library/Application Support/Plex Media Server"
BACKUP_DATE="$${NOMAD_META_backup_date:-}"

# Determine which backup to restore
if [ -n "$BACKUP_DATE" ]; then
    RESTORE_SOURCE="$BACKUP_DIR/$BACKUP_DATE"
    echo "Restoring from specified backup: $BACKUP_DATE"
else
    # Find the latest backup
    RESTORE_SOURCE=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | head -1)
    if [ -z "$RESTORE_SOURCE" ]; then
        echo "ERROR: No backups found in $BACKUP_DIR"
        exit 1
    fi
    echo "Restoring from latest backup: $(basename $RESTORE_SOURCE)"
fi

# Verify backup exists
if [ ! -d "$RESTORE_SOURCE" ]; then
    echo "ERROR: Backup directory not found: $RESTORE_SOURCE"
    echo "Available backups:"
    ls -la "$BACKUP_DIR" 2>/dev/null || echo "  No backups found"
    exit 1
fi

echo "Backup source: $RESTORE_SOURCE"
echo ""

# Create target directories if they don't exist
echo "Preparing restore directories..."
mkdir -p "$PLEX_MEDIA_SERVER/Plug-in Support/Databases"

# Restore database files
if [ -d "$RESTORE_SOURCE/Databases" ]; then
    echo "Restoring Plex databases..."
    rsync -av --progress "$RESTORE_SOURCE/Databases/" "$PLEX_MEDIA_SERVER/Plug-in Support/Databases/"
    echo "Database restore complete."
else
    echo "Warning: No database backup found in $RESTORE_SOURCE/Databases"
fi

# Restore preferences file
if [ -f "$RESTORE_SOURCE/Preferences.xml" ]; then
    echo "Restoring Preferences.xml..."
    cp "$RESTORE_SOURCE/Preferences.xml" "$PLEX_MEDIA_SERVER/"
    echo "Preferences restore complete."
else
    echo "Warning: No Preferences.xml found in backup"
fi

# Fix ownership (use the configured UID/GID)
echo "Fixing file ownership..."
chown -R [[ var "plex_uid" . ]]:[[ var "plex_gid" . ]] "$PLEX_CONFIG" 2>/dev/null || echo "Warning: Could not set ownership"

echo ""
echo "=========================================="
echo "Restore complete!"
echo "=========================================="
EOF
        destination = "local/restore-plex.sh"
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
