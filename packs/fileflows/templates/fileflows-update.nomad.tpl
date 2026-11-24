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
        args  = ["/bin/sh", "-c", "sleep 1 && /bin/sh /local/update-fileflows-version.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

echo "Starting FileFlows version update job..."

# Install required tools
apt-get update -qq && apt-get install -y -qq curl jq unzip >/dev/null 2>&1

# Fetch latest stable container version from Docker Hub.
# Only numeric YY.MM(.N) tags - never 'latest', 'preview' or 'modded'.
TAG=$(curl -s "https://hub.docker.com/v2/repositories/revenz/fileflows/tags?page_size=100" | \
  jq -r '.results[].name' | \
  grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | \
  head -1)

if [ -z "$TAG" ]; then
  echo "Error: Failed to find stable container tag from Docker Hub"
  exit 1
fi

echo "Latest revenz/fileflows version: $TAG"

# Fetch and install Nomad CLI
NOMAD_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
curl -sL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
unzip -q /tmp/nomad.zip -d /tmp/
chmod +x /tmp/nomad

# The image tag currently deployed in the running job is the source of truth
CURRENT_TAG=$(/tmp/nomad job inspect "[[ var "job_name" . ]]" | \
  jq -r '.Job.TaskGroups[].Tasks[].Config.image' | \
  sed 's/.*://')

echo "Currently deployed tag: $CURRENT_TAG"

if [ "$TAG" = "$CURRENT_TAG" ]; then
  echo "Already up to date, nothing to do."
  /tmp/nomad var put -force [[ var "nomad_variable_path" . ]] version="$TAG"
  exit 0
fi

echo "New version available: $CURRENT_TAG -> $TAG"

# Record both the new version and the previous one (for rollback)
/tmp/nomad var put -force [[ var "nomad_variable_path" . ]] version="$TAG" previous_version="$CURRENT_TAG"
echo "Updated Nomad variable [[ var "nomad_variable_path" . ]]: version=$TAG previous_version=$CURRENT_TAG"

AUTO_APPLY="[[ var "auto_apply_update" . ]]"
if [ "$AUTO_APPLY" != "true" ]; then
  echo "auto_apply_update is false - NOT applying. To upgrade, redeploy the fileflows pack with:"
  echo "  nomad-pack run packs/fileflows --name=fileflows -var image=docker.io/revenz/fileflows:$TAG"
  echo "To roll back if an upgrade breaks: use previous_version from the Nomad variable."
  exit 0
fi

echo "Applying new image tag by re-submitting the running job spec..."
/tmp/nomad job inspect "[[ var "job_name" . ]]" | \
  jq --arg image "docker.io/revenz/fileflows:$TAG" '.Job.TaskGroups[].Tasks[].Config.image = $image' | \
  /tmp/nomad job run -

echo "Submitted job with image docker.io/revenz/fileflows:$TAG"
EOF
        destination = "local/update-fileflows-version.sh"
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
