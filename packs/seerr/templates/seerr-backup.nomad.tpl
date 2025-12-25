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

    volume "seerr-config" {
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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup.sh"]
      }

      volume_mount {
        volume      = "seerr-config"
        destination = "/seerr-config"
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

echo "Starting Seerr backup job..."

apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

BACKUP_DIR="/backups/seerr"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

mkdir -p "$BACKUP_DEST"

if [ -f "/seerr-config/db/db.sqlite3" ]; then
    echo "Backing up Seerr database..."
    mkdir -p "$BACKUP_DEST/db"
    cp "/seerr-config/db/db.sqlite3" "$BACKUP_DEST/db/"
fi

if [ -f "/seerr-config/settings.json" ]; then
    echo "Backing up settings.json..."
    cp "/seerr-config/settings.json" "$BACKUP_DEST/"
fi

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
