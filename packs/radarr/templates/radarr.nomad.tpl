job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "radarr" {
    count = 1

    volume "radarr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    volume "media-drive" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "downloads" {
      type            = "host"
      source          = "[[ var "downloads_volume_name" . ]]"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "port" . ]]
      }
    }

    task "radarr" {
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
        volume      = "radarr-config"
        destination = "/config"
      }

      volume_mount {
        volume      = "media-drive"
        destination = "/media"
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
      }

      template {
        data = <<EOH
TZ=[[ var "timezone" . ]]
PUID=[[ var "radarr_uid" . ]]
PGID=[[ var "radarr_gid" . ]]
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
