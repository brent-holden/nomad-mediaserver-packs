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

    volume "fileflows-config" {
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
        volume      = "fileflows-config"
        destination = "/fileflows-config"
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
echo "FileFlows Restore Job"
echo "=========================================="

# Install required tools
echo "Installing rsync..."
apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

# Configuration
BACKUP_DIR="/backups/fileflows"
CONFIG_DIR="/fileflows-config"
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
if [ -f "$RESTORE_SOURCE/FileFlows.db" ]; then
    echo "Restoring FileFlows database..."
    # Restore the database to the current layout (Data/FileFlows.sqlite)
    mkdir -p "$CONFIG_DIR/Data"
    cp "$RESTORE_SOURCE/FileFlows.sqlite" "$CONFIG_DIR/Data/"
    echo "Database restore complete."
else
    echo "Warning: No FileFlows.db found in backup"
fi

# Restore config file
if [ -f "$RESTORE_SOURCE/fileflows.config" ]; then
    echo "Restoring fileflows.config..."
    cp "$RESTORE_SOURCE/server.config" "$CONFIG_DIR/" 2>/dev/null || echo "Note: no server.config in backup"
    echo "Config restore complete."
else
    echo "Warning: No fileflows.config found in backup"
fi

# Restore flows
if [ -d "$RESTORE_SOURCE/Flows" ]; then
    echo "Restoring Flows..."
    mkdir -p "$CONFIG_DIR/Flows"
    rsync -av "$RESTORE_SOURCE/Flows/" "$CONFIG_DIR/Flows/"
    echo "Flows restore complete."
else
    echo "Note: No Flows directory found in backup"
fi

# Restore libraries
if [ -d "$RESTORE_SOURCE/Libraries" ]; then
    echo "Restoring Libraries..."
    mkdir -p "$CONFIG_DIR/Libraries"
    rsync -av "$RESTORE_SOURCE/Libraries/" "$CONFIG_DIR/Libraries/"
    echo "Libraries restore complete."
else
    echo "Note: No Libraries directory found in backup"
fi

# Restore plugins
if [ -d "$RESTORE_SOURCE/Plugins" ]; then
    echo "Restoring Plugins..."
    mkdir -p "$CONFIG_DIR/Plugins"
    rsync -av "$RESTORE_SOURCE/Plugins/" "$CONFIG_DIR/Plugins/"
    echo "Plugins restore complete."
else
    echo "Note: No Plugins directory found in backup"
fi

# Restore scripts
if [ -d "$RESTORE_SOURCE/Scripts" ]; then
    echo "Restoring Scripts..."
    mkdir -p "$CONFIG_DIR/Scripts"
    rsync -av "$RESTORE_SOURCE/Scripts/" "$CONFIG_DIR/Scripts/"
    echo "Scripts restore complete."
else
    echo "Note: No Scripts directory found in backup"
fi

# Fix ownership
echo "Fixing file ownership..."
chown -R [[ var "fileflows_uid" . ]]:[[ var "fileflows_gid" . ]] "$CONFIG_DIR" 2>/dev/null || echo "Warning: Could not set ownership"

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
