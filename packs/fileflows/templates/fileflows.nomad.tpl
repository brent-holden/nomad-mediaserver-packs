job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    operator  = "regexp"
    value     = "[[ join "|" (var "node_hostnames" .) ]]"
  }

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  group "fileflows" {
    count = 1

    volume "media-drive" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "fileflows-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "port" . ]]
      }
    }

    task "fileflows" {
      driver = "podman"

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      config {
        # Keep the image pinned to a numeric tag (never :latest) and
        # force_pull off: restarts must not silently upgrade FileFlows.
        # Upgrades re-run every DockerMod install, and one failed mod
        # blocks ALL file processing while the job stays green.
        image        = "[[ var "image" . ]]"
        force_pull   = [[ var "force_pull" . ]]
        ports        = ["http"]
        network_mode = "host"
[[- if var "gpu_transcoding" . ]]
        devices      = [[ var "gpu_devices" . | toJson ]]
[[- end ]]
        volumes      = [
          "[[ var "temp_path" . ]]:/temp",
        ]
      }

      volume_mount {
        volume      = "fileflows-config"
        destination = "/app/Data"
      }

      volume_mount {
        volume      = "media-drive"
        destination = "/media"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
PUID=[[ var "fileflows_uid" . ]]
PGID=[[ var "fileflows_gid" . ]]
DOCKER_IMAGE_VERSION={{- with nomadVar "[[ var "nomad_variable_path" . ]]" -}}{{ .version }}{{- end }}
EOH
        destination = "local/env_vars"
        env         = true
      }

[[- if var "register_consul_service" . ]]
      service {
        name = "[[ var "consul_service_name" . ]]"
        port = "http"

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"

          # Restart the task if the web UI stays unresponsive, e.g. when
          # heavy transcoding starves the server into a wedged state
          check_restart {
            limit = 5
            grace = "120s"
          }
        }
      }
[[- end ]]
    }
  }
}
