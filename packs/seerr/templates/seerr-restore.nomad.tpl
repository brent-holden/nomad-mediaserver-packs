[[- if var "enable_restore" . ]]
job "[[ var "job_name" . ]]-restore" {
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

    volume "seerr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/restore.sh"]
      }

      volume_mount {
        volume      = "seerr-config"
        destination = "/seerr-config"
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
echo "Seerr Restore Job"
echo "=========================================="

# Install required tools
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Configuration
BACKUP_DIR="/backups/seerr"
CONFIG_DIR="/seerr-config"
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

# Restore database file
if [ -f "$RESTORE_SOURCE/db/db.sqlite3" ]; then
    echo "Restoring Seerr database..."
    mkdir -p "$CONFIG_DIR/db"
    cp "$RESTORE_SOURCE/db/db.sqlite3" "$CONFIG_DIR/db/"
    echo "Database restore complete."
else
    echo "Warning: No db.sqlite3 found in backup"
fi

# Restore settings file
if [ -f "$RESTORE_SOURCE/settings.json" ]; then
    echo "Restoring settings.json..."
    cp "$RESTORE_SOURCE/settings.json" "$CONFIG_DIR/"
    echo "Settings restore complete."
else
    echo "Warning: No settings.json found in backup"
fi

# Fix ownership
echo "Fixing file ownership..."
chown -R [[ var "seerr_uid" . ]]:[[ var "seerr_gid" . ]] "$CONFIG_DIR" 2>/dev/null || echo "Warning: Could not set ownership"

echo ""
echo "=========================================="
echo "Restore complete!"
echo "=========================================="
EOF
        destination = "local/restore.sh"
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
