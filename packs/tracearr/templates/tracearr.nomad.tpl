job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "tracearr" {
    count = 1

    volume "tracearr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "tracearr-postgres" {
      type            = "host"
      source          = "[[ var "postgres_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "tracearr-redis" {
      type            = "host"
      source          = "[[ var "redis_volume_name" . ]]"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "port" . ]]
      }
      port "postgres" {
        static = [[ var "postgres_port" . ]]
      }
      port "redis" {
        static = [[ var "redis_port" . ]]
      }
    }

    # Tracearr exits if the database isn't accepting connections yet; let
    # Nomad retry while TimescaleDB finishes initializing on first boot.
    restart {
      attempts = 10
      interval = "10m"
      delay    = "15s"
      mode     = "delay"
    }

    task "postgres" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      resources {
        cpu    = [[ var "postgres_cpu" . ]]
        memory = [[ var "postgres_memory" . ]]
      }

      config {
        image        = "[[ var "postgres_image" . ]]"
        ports        = ["postgres"]
        network_mode = "host"
        shm_size     = "512m"
        ulimit = {
          nofile = "65536:65536"
        }
        args = [
          "postgres",
          "-c", "listen_addresses=127.0.0.1",
          "-c", "port=[[ var "postgres_port" . ]]",
          "-c", "timescaledb.license=timescale",
          "-c", "timescaledb.max_tuples_decompressed_per_dml_transaction=100000",
          "-c", "max_locks_per_transaction=4096",
          "-c", "timescaledb.telemetry_level=off",
          "-c", "max_connections=150",
        ]
      }

      volume_mount {
        volume      = "tracearr-postgres"
        destination = "/home/postgres/pgdata/data"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
POSTGRES_USER=tracearr
POSTGRES_DB=tracearr
{{- with nomadVar "[[ var "secrets_variable_path" . ]]" }}
POSTGRES_PASSWORD={{ .db_password }}
{{- end }}
EOH
        destination = "secrets/env_vars"
        env         = true
      }
    }

    task "redis" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      resources {
        cpu    = 200
        memory = 256
      }

      config {
        image        = "[[ var "redis_image" . ]]"
        ports        = ["redis"]
        network_mode = "host"
        args = [
          "redis-server",
          "--bind", "127.0.0.1",
          "--port", "[[ var "redis_port" . ]]",
          "--appendonly", "yes",
        ]
      }

      volume_mount {
        volume      = "tracearr-redis"
        destination = "/data"
      }
    }

    task "tracearr" {
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
        volume      = "tracearr-config"
        destination = "/data/tracearr"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
NODE_ENV=production
HOST=0.0.0.0
PORT=[[ var "port" . ]]
LOG_LEVEL=[[ var "log_level" . ]]
CORS_ORIGIN=*
REDIS_URL=redis://127.0.0.1:[[ var "redis_port" . ]]
DOCKER_IMAGE_VERSION={{- with nomadVar "[[ var "nomad_variable_path" . ]]" -}}{{ .version }}{{- end }}

# Secrets are read from Nomad variables so they stay out of job specs.
# Set them with:
#   nomad var put [[ var "secrets_variable_path" . ]] \
#     jwt_secret=$(openssl rand -hex 32) \
#     cookie_secret=$(openssl rand -hex 32) \
#     db_password=$(openssl rand -hex 24)
{{- with nomadVar "[[ var "secrets_variable_path" . ]]" }}
DATABASE_URL=postgres://tracearr:{{ .db_password }}@127.0.0.1:[[ var "postgres_port" . ]]/tracearr
JWT_SECRET={{ .jwt_secret }}
COOKIE_SECRET={{ .cookie_secret }}
{{- end }}
EOH
        destination = "secrets/env_vars"
        env         = true
      }

[[- if var "register_consul_service" . ]]
      service {
        name = "[[ var "consul_service_name" . ]]"
        port = "http"

        check {
          type     = "http"
          path     = "/health"
          interval = "60s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
