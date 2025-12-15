job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "plex" {
    count = 1

    volume "media-drive" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "plex-config" {
      type   = "host"
      source = "[[ var "config_volume_name" . ]]"
    }

    volume "plex-transcode" {
      type   = "host"
      source = "[[ var "transcode_volume_name" . ]]"
    }

    network {
      mode = "host"
      port "plex" {
        static = [[ var "port" . ]]
      }
    }

    task "plex" {
      driver = "podman"

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      config {
        image        = "[[ var "image" . ]]"
        ports        = ["plex"]
        network_mode = "host"
[[- if var "gpu_transcoding" . ]]
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
TZ=[[ var "timezone" . ]]
PLEX_CLAIM={{- with nomadVar "nomad/jobs/plex" -}}{{ .claim_token }}{{- end }}
VERSION={{- with nomadVar "nomad/jobs/plex" -}}{{ .version }}{{- end }}
PLEX_UID=[[ var "plex_uid" . ]]
PLEX_GID=[[ var "plex_gid" . ]]
EOH
        destination = "local/env_vars"
        env         = true
      }

[[- if var "register_consul_service" . ]]
      service {
        name = "[[ var "consul_service_name" . ]]"
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
