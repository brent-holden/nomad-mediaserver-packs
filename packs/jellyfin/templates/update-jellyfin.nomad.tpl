[[- if var "enable_update" . ]]
job "[[ var "job_name" . ]]-update" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ var "update_cron_schedule" . ]]"]
    time_zone        = "[[ var "timezone" . ]]"
    prohibit_overlap = true
  }

  group "update" {
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

    task "fetch-version" {
      driver = "podman"

      config {
        image = "docker.io/debian:bookworm-slim"
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/update-jellyfin-version.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting Jellyfin version update job..."

# Install required tools
echo "Installing curl, jq, and unzip..."
apt-get update -qq && apt-get install -y -qq curl jq unzip > /dev/null 2>&1

# Fetch latest stable container version from Docker Hub
# LinuxServer tags stable versions as X.X.X (without -nightly suffixes)
echo "Fetching latest Jellyfin container version from Docker Hub..."
CONTAINER_VERSION=$(curl -s "https://hub.docker.com/v2/repositories/linuxserver/jellyfin/tags?page_size=100" | \
    jq -r '.results[].name' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
    head -1)

if [ -z "$CONTAINER_VERSION" ]; then
    echo "Error: Failed to find stable container version from Docker Hub"
    exit 1
fi

echo "Latest linuxserver/jellyfin container version: $CONTAINER_VERSION"

# Fetch and install latest Nomad CLI
echo "Fetching latest Nomad version..."
NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
echo "Installing Nomad $NOMAD_VERSION..."
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

echo "Writing version to Nomad variable..."
/tmp/nomad var put -force [[ var "nomad_variable_path" . ]] version="$CONTAINER_VERSION"

echo "Successfully updated Nomad variable [[ var "nomad_variable_path" . ]] with container version: $CONTAINER_VERSION"
EOF
        destination = "local/update-jellyfin-version.sh"
        perms       = "0755"
      }

      env {
        NOMAD_ADDR = "http://${attr.unique.network.ip-address}:4646"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
[[- end ]]
