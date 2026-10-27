job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "polaris.lan.eventide.network"
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
        image        = "[[ var "image" . ]]"
        force_pull   = true
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
