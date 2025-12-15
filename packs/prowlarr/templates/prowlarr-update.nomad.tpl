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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/update.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Fetching latest Prowlarr container version..."

apt-get update -qq && apt-get install -y -qq curl jq unzip > /dev/null 2>&1

# Fetch latest stable container version from Docker Hub
# LinuxServer tags stable versions as X.X.X.X (without -develop, -nightly suffixes)
VERSION=$(curl -s "https://hub.docker.com/v2/repositories/linuxserver/prowlarr/tags?page_size=100" | \
    jq -r '.results[].name' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    head -1)

if [ -z "$VERSION" ]; then
    echo "Error: Failed to find stable container version"
    exit 1
fi

echo "Latest linuxserver/prowlarr container version: $VERSION"

NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

/tmp/nomad var put -force [[ var "nomad_variable_path" . ]] version="$VERSION"

echo "Updated Nomad variable with container version: $VERSION"
EOF
        destination = "local/update.sh"
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
