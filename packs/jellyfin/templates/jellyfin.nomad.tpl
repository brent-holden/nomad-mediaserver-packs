job "[[ .jellyfin.job_name ]]" {
  region      = "[[ .jellyfin.region ]]"
  datacenters = [[ .jellyfin.datacenters | toJson ]]
  namespace   = "[[ .jellyfin.namespace ]]"
  type        = "service"

  group "jellyfin" {
    count = 1

    volume "media-drive" {
      type            = "csi"
      source          = "[[ .jellyfin.media_volume_name ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "jellyfin-config" {
      type   = "host"
      source = "[[ .jellyfin.config_volume_name ]]"
    }

    volume "jellyfin-cache" {
      type   = "host"
      source = "[[ .jellyfin.cache_volume_name ]]"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ .jellyfin.http_port ]]
      }
      port "discovery" {
        static = [[ .jellyfin.discovery_port ]]
      }
    }

    task "jellyfin" {
      driver = "podman"

      resources {
        cpu    = [[ .jellyfin.cpu ]]
        memory = [[ .jellyfin.memory ]]
      }

      config {
        image        = "[[ .jellyfin.image ]]"
        ports        = ["http", "discovery"]
        network_mode = "host"
      }

      volume_mount {
        volume      = "jellyfin-config"
        destination = "/config"
      }

      volume_mount {
        volume      = "jellyfin-cache"
        destination = "/cache"
      }

      volume_mount {
        volume      = "media-drive"
        destination = "/media"
      }

      template {
        data = <<EOH
TZ=[[ .jellyfin.timezone ]]
EOH
        destination = "local/env_vars"
        env         = true
      }

[[- if .jellyfin.register_consul_service ]]
      service {
        name = "[[ .jellyfin.consul_service_name ]]"
        port = "http"

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
