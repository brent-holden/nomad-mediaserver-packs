job "[[ .plex.job_name ]]" {
  region      = "[[ .plex.region ]]"
  datacenters = [[ .plex.datacenters | toJson ]]
  namespace   = "[[ .plex.namespace ]]"
  type        = "service"

  group "plex" {
    count = 1

    volume "media-drive" {
      type            = "csi"
      source          = "[[ .plex.media_volume_name ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "plex-config" {
      type   = "host"
      source = "[[ .plex.config_volume_name ]]"
    }

    volume "plex-transcode" {
      type   = "host"
      source = "[[ .plex.transcode_volume_name ]]"
    }

    network {
      mode = "host"
      port "plex" {
        static = [[ .plex.port ]]
      }
    }

    task "plex" {
      driver = "podman"

      resources {
        cpu    = [[ .plex.cpu ]]
        memory = [[ .plex.memory ]]
      }

      config {
        image        = "[[ .plex.image ]]"
        ports        = ["plex"]
        network_mode = "host"
[[- if .plex.gpu_transcoding ]]
        devices      = ["/dev/dri:/dev/dri"]
[[- end ]]
      }

      volume_mount {
        volume      = "plex-config"
        destination = "/config"
      }

      volume_mount {
        volume      = "plex-transcode"
        destination = "/transcode"
      }

      volume_mount {
        volume      = "media-drive"
        destination = "/media"
      }

      template {
        data = <<EOH
TZ=[[ .plex.timezone ]]
PLEX_CLAIM={{- with nomadVar "nomad/jobs/plex" -}}{{ .claim_token }}{{- end }}
VERSION={{- with nomadVar "nomad/jobs/plex" -}}{{ .version }}{{- end }}
PLEX_UID=[[ .plex.plex_uid ]]
PLEX_GID=[[ .plex.plex_gid ]]
EOH
        destination = "local/env_vars"
        env         = true
      }

[[- if .plex.register_consul_service ]]
      service {
        name = "[[ .plex.consul_service_name ]]"
        port = "plex"

        check {
          type     = "http"
          path     = "/identity"
          interval = "30s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
