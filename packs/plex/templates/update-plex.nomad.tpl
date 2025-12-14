[[- if .plex.enable_update ]]
job "update-[[ .plex.job_name ]]" {
  region      = "[[ .plex.region ]]"
  datacenters = [[ .plex.datacenters | toJson ]]
  namespace   = "[[ .plex.namespace ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ .plex.update_cron_schedule ]]"]
    time_zone        = "[[ .plex.timezone ]]"
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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/update-plex-version.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting Plex version update job..."

# Install required tools
echo "Installing curl, jq, and unzip..."
apt-get update -qq && apt-get install -y -qq curl jq unzip > /dev/null 2>&1

echo "Fetching Plex version from API..."
PLEX_VERSION=$(curl -s "https://plex.tv/api/downloads/5.json?channel=plexpass" | jq -r '.computer.Linux.version')

if [ -z "$PLEX_VERSION" ] || [ "$PLEX_VERSION" = "null" ]; then
    echo "Error: Failed to extract Plex version from API response"
    exit 1
fi

echo "Extracted Plex version: $PLEX_VERSION"

# Get existing claim token from Nomad variable (rendered by template)
EXISTING_TOKEN="{{- with nomadVar "[[ .plex.nomad_variable_path ]]" -}}{{ .claim_token }}{{- end -}}"

if [ -z "$EXISTING_TOKEN" ]; then
    echo "Warning: No existing claim token found, using placeholder"
    EXISTING_TOKEN="claim-XXXXX"
fi

# Fetch and install latest Nomad CLI
echo "Fetching latest Nomad version..."
NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
echo "Installing Nomad $NOMAD_VERSION..."
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

echo "Writing version to Nomad variable..."
/tmp/nomad var put -force [[ .plex.nomad_variable_path ]] claim_token="$EXISTING_TOKEN" version="$PLEX_VERSION"

echo "Successfully updated Nomad variable [[ .plex.nomad_variable_path ]] with version: $PLEX_VERSION"
EOF
        destination = "local/update-plex-version.sh"
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
