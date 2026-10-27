job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "questarr" {
    count = 1

    volume "questarr-config" {
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

    task "questarr" {
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
      }

      volume_mount {
        volume      = "questarr-config"
        destination = "/app/data"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
PORT=[[ var "port" . ]]
PUID=[[ var "questarr_uid" . ]]
PGID=[[ var "questarr_gid" . ]]
SQLITE_DB_PATH=/app/data/sqlite.db
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
          path     = "/api/health"
          interval = "60s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
