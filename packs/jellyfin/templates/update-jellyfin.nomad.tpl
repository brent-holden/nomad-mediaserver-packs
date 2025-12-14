[[- if .jellyfin.enable_update ]]
job "update-[[ .jellyfin.job_name ]]" {
  region      = "[[ .jellyfin.region ]]"
  datacenters = [[ .jellyfin.datacenters | toJson ]]
  namespace   = "[[ .jellyfin.namespace ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ .jellyfin.update_cron_schedule ]]"]
    time_zone        = "[[ .jellyfin.timezone ]]"
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

echo "Fetching latest Jellyfin version from GitHub..."
JELLYFIN_VERSION=$(curl -s "https://api.github.com/repos/jellyfin/jellyfin/releases/latest" | jq -r '.name')

if [ -z "$JELLYFIN_VERSION" ] || [ "$JELLYFIN_VERSION" = "null" ]; then
    echo "Error: Failed to extract Jellyfin version from GitHub API response"
    exit 1
fi

echo "Latest Jellyfin version: $JELLYFIN_VERSION"

# Fetch and install latest Nomad CLI
echo "Fetching latest Nomad version..."
NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
echo "Installing Nomad $NOMAD_VERSION..."
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

echo "Writing version to Nomad variable..."
/tmp/nomad var put -force [[ .jellyfin.nomad_variable_path ]] version="$JELLYFIN_VERSION"

echo "Successfully updated Nomad variable [[ .jellyfin.nomad_variable_path ]] with version: $JELLYFIN_VERSION"
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
