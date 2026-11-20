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
    }

    network {
      mode = "host"
    }

    task "backup" {
      driver = "podman"
      user   = "root"

      config {
        # Same image as the database so pg_dump matches the server version
        image        = "[[ var "postgres_image" . ]]"
        network_mode = "host"
        entrypoint   = ["/bin/sh"]
        args         = ["-c", "sleep 1 && /bin/sh /local/backup.sh"]
      }

      volume_mount {
        volume      = "tracearr-config"
        destination = "/tracearr-config"
        read_only   = true
      }

      volume_mount {
        volume      = "backup-drive"
        destination = "/backups"
      }

      template {
        data = <<EOH
PGHOST=127.0.0.1
PGPORT=[[ var "postgres_port" . ]]
PGUSER=tracearr
PGDATABASE=tracearr
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

echo "Starting Tracearr backup job..."

BACKUP_DIR="/backups/tracearr"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

mkdir -p "$BACKUP_DEST"

# Dump to local disk first, then copy onto the CIFS backup share
echo "Dumping Tracearr database..."
pg_dump --format=custom --file=/tmp/tracearr.dump
cp /tmp/tracearr.dump "$BACKUP_DEST/tracearr.dump"

echo "Cleaning up old backups (keeping last [[ var "backup_retention_days" . ]] days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ var "backup_retention_days" . ]] -exec rm -rf {} \; 2>/dev/null || true

echo "Backup complete:"
du -sh "$BACKUP_DEST"
EOF
        destination = "local/backup.sh"
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
