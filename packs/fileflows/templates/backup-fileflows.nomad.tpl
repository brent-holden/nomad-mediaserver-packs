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

    task "backup" {
      driver = "podman"

      config {
        image = "docker.io/debian:bookworm-slim"
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/backup-fileflows.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting FileFlows backup job..."

echo "Installing sqlite3 and rsync..."
apt-get update -qq && apt-get install -y -qq sqlite3 rsync >/dev/null 2>&1

# Current FileFlows data layout (config host volume is mounted at
# /fileflows-config, which corresponds to /app/Data in the service container):
#   Data/FileFlows.sqlite   - main database
#   server.config           - server configuration
#   Data/Config             - runtime configuration
#   Plugins                 - installed plugins
#   Templates               - flow templates
DB="/fileflows-config/Data/FileFlows.sqlite"
SERVER_CONFIG="/fileflows-config/server.config"
CONFIG_DIR="/fileflows-config/Data/Config"
PLUGINS_DIR="/fileflows-config/Plugins"
TEMPLATES_DIR="/fileflows-config/Templates"

BACKUP_DIR="/backups/fileflows"
DATE=$(date +%Y-%m-%d)
BACKUP_DEST="$BACKUP_DIR/$DATE"

echo "Creating backup directory: $BACKUP_DEST"
mkdir -p "$BACKUP_DEST"

# Consistent database snapshot via SQLite backup API
# (safe even while FileFlows is running and writing)
if [ -f "$DB" ]; then
  echo "Backing up FileFlows database..."
  sqlite3 "$DB" ".backup '$BACKUP_DEST/FileFlows.sqlite'"
  echo "Database backup complete."
else
  echo "ERROR: FileFlows database not found at $DB"
  exit 1
fi

for f in "$SERVER_CONFIG"; do
  if [ -f "$f" ]; then
    echo "Backing up $(basename "$f")..."
    cp "$f" "$BACKUP_DEST/"
  else
    echo "Warning: $f not found, skipping"
  fi
done

for d in "$CONFIG_DIR" "$PLUGINS_DIR" "$TEMPLATES_DIR"; do
  if [ -d "$d" ]; then
    echo "Backing up $(basename "$d")..."
    rsync -a "$d/" "$BACKUP_DEST/$(basename "$d")/"
  else
    echo "Warning: $d not found, skipping"
  fi
done

echo "Pruning backups older than [[ var "backup_retention_days" . ]] days..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +[[ var "backup_retention_days" . ]] -exec rm -rf {} + 2>/dev/null || true

echo "FileFlows backup complete: $BACKUP_DEST"
EOF
        destination = "local/backup-fileflows.sh"
        perms       = "0755"
      }

      volume_mount {
        volume      = "config"
        destination = "/fileflows-config"
        read_only   = true
      }

      volume_mount {
        volume      = "backups"
        destination = "/backups"
        read_only   = false
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      read_only       = true
      attachment_mode = "file-system"
      access_mode     = "single-node-multi-writer"
    }

    volume "backups" {
      type            = "csi"
      source          = "[[ var "backup_volume_name" . ]]"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }
  }
}
[[- end ]]
