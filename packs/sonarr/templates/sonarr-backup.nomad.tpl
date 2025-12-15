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

    volume "sonarr-config" {
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
        volume      = "sonarr-config"
        destination = "/sonarr-config"
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

echo "Starting Sonarr backup job..."

apt-get update -qq && apt-get install -y -qq rsync > /dev/null 2>&1

BACKUP_DIR="/backups/sonarr"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

mkdir -p "$BACKUP_DEST"

if [ -f "/sonarr-config/sonarr.db" ]; then
    echo "Backing up Sonarr database..."
    cp "/sonarr-config/sonarr.db" "$BACKUP_DEST/"
fi

if [ -f "/sonarr-config/config.xml" ]; then
    echo "Backing up config.xml..."
    cp "/sonarr-config/config.xml" "$BACKUP_DEST/"
fi

if [ -d "/sonarr-config/Backups" ]; then
    echo "Backing up Sonarr internal backups..."
    rsync -av "/sonarr-config/Backups/" "$BACKUP_DEST/Backups/"
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
