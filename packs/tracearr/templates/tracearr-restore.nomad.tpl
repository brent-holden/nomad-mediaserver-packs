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

    # Mounting the config volume pins this job to the node running Tracearr,
    # where TimescaleDB listens on 127.0.0.1.
    volume "tracearr-config" {
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
      read_only       = true
    }

    network {
      mode = "host"
    }

    task "restore" {
      driver = "podman"
      user   = "root"

      config {
        image        = "[[ var "postgres_image" . ]]"
        network_mode = "host"
        entrypoint   = ["/bin/sh"]
        args         = ["-c", "sleep 1 && /bin/sh /local/restore.sh"]
      }

      volume_mount {
        volume      = "tracearr-config"
        destination = "/tracearr-config"
        read_only   = true
      }

      volume_mount {
        volume      = "backup-drive"
        destination = "/backups"
        read_only   = true
      }

      template {
        data = <<EOH
PGHOST=127.0.0.1
PGPORT=[[ var "postgres_port" . ]]
PGUSER=tracearr
{{- with nomadVar "[[ var "secrets_variable_path" . ]]" }}
PGPASSWORD={{ .db_password }}
{{- end }}
EOH
        destination = "secrets/env_vars"
        env         = true
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "=========================================="
echo "Tracearr Restore Job"
echo "=========================================="

BACKUP_DIR="/backups/tracearr"
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

if [ ! -f "$RESTORE_SOURCE/tracearr.dump" ]; then
    echo "ERROR: Backup not found: $RESTORE_SOURCE/tracearr.dump"
    echo "Available backups:"
    ls -la "$BACKUP_DIR" 2>/dev/null || echo "  No backups found"
    exit 1
fi

cp "$RESTORE_SOURCE/tracearr.dump" /tmp/tracearr.dump

# Restore into a scratch database, then swap it in, so Tracearr reconnecting
# mid-restore can't run migrations against a half-populated database.
echo "Creating scratch database tracearr_restore..."
psql -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS tracearr_restore;"
psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE tracearr_restore OWNER tracearr;"
psql -d tracearr_restore -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

echo "Restoring database dump..."
psql -d tracearr_restore -v ON_ERROR_STOP=1 -c "SELECT timescaledb_pre_restore();"
pg_restore --no-owner --role=tracearr -d tracearr_restore /tmp/tracearr.dump || echo "pg_restore reported warnings (usually harmless with TimescaleDB)"
psql -d tracearr_restore -v ON_ERROR_STOP=1 -c "SELECT timescaledb_post_restore();"

echo "Swapping restored database into place..."
psql -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS tracearr WITH (FORCE);"
psql -d postgres -v ON_ERROR_STOP=1 -c "ALTER DATABASE tracearr_restore RENAME TO tracearr;"

# Renaming a database stops TimescaleDB's background workers (compression, retention)
psql -d tracearr -v ON_ERROR_STOP=1 -c "SELECT _timescaledb_functions.start_background_workers();"

echo ""
echo "=========================================="
echo "Restore complete!"
echo "Restart Tracearr to pick up the restored database:"
echo "  nomad alloc restart <alloc-id> tracearr"
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
