job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "sonarr" {
    count = 1

    volume "sonarr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "media-drive" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "port" . ]]
      }
    }

    task "sonarr" {
      driver = "podman"

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      config {
        image        = "[[ var "image" . ]]"
        ports        = ["http"]
        network_mode = "host"
      }

      volume_mount {
        volume      = "sonarr-config"
        destination = "/config"
      }

      volume_mount {
        volume      = "media-drive"
        destination = "/media"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
PUID=[[ var "sonarr_uid" . ]]
PGID=[[ var "sonarr_gid" . ]]
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
          path     = "/ping"
          interval = "30s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
