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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/update-sabnzbd-version.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting SABnzbd version update job..."

# Install required tools
echo "Installing curl, jq, and unzip..."
apt-get update -qq && apt-get install -y -qq curl jq unzip > /dev/null 2>&1

echo "Fetching latest SABnzbd version from GitHub..."
SABNZBD_VERSION=$(curl -s "https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest" | jq -r '.tag_name')

if [ -z "$SABNZBD_VERSION" ] || [ "$SABNZBD_VERSION" = "null" ]; then
    echo "Error: Failed to extract SABnzbd version from GitHub API response"
    exit 1
fi

echo "Latest SABnzbd version: $SABNZBD_VERSION"

# Fetch and install latest Nomad CLI
echo "Fetching latest Nomad version..."
NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
echo "Installing Nomad $NOMAD_VERSION..."
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

echo "Writing version to Nomad variable..."
/tmp/nomad var put -force [[ var "nomad_variable_path" . ]] version="$SABNZBD_VERSION"

echo "Successfully updated Nomad variable [[ var "nomad_variable_path" . ]] with version: $SABNZBD_VERSION"
EOF
        destination = "local/update-sabnzbd-version.sh"
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
