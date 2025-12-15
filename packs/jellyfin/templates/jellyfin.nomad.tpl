job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "jellyfin" {
    count = 1

    volume "media-drive" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    volume "jellyfin-config" {
      type   = "host"
      source = "[[ var "config_volume_name" . ]]"
    }

    volume "jellyfin-cache" {
      type   = "host"
      source = "[[ var "cache_volume_name" . ]]"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "http_port" . ]]
      }
      port "discovery" {
        static = [[ var "discovery_port" . ]]
      }
    }

    # Create dynamic host volumes before main task starts
    task "create-volumes" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "exec"

      config {
        command = "/bin/sh"
        args    = ["-c", "nomad volume create -detach /local/config-volume.hcl 2>/dev/null || true; nomad volume create -detach /local/cache-volume.hcl 2>/dev/null || true"]
      }

      template {
        data = <<EOH
name      = "[[ var "config_volume_name" . ]]"
type      = "host"
plugin_id = "mkdir"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

parameters {
  mode = "0755"
  uid  = "[[ var "jellyfin_uid" . ]]"
  gid  = "[[ var "jellyfin_gid" . ]]"
}
EOH
        destination = "local/config-volume.hcl"
      }

      template {
        data = <<EOH
name      = "[[ var "cache_volume_name" . ]]"
type      = "host"
plugin_id = "mkdir"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

parameters {
  mode = "0755"
  uid  = "[[ var "jellyfin_uid" . ]]"
  gid  = "[[ var "jellyfin_gid" . ]]"
}
EOH
        destination = "local/cache-volume.hcl"
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    task "jellyfin" {
      driver = "podman"

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      config {
        image        = "[[ var "image" . ]]"
        ports        = ["http", "discovery"]
        network_mode = "host"
[[- if var "gpu_transcoding" . ]]
        devices      = ["/dev/dri:/dev/dri"]
[[- end ]]
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
TZ=[[ var "timezone" . ]]
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
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
[[- end ]]
    }
  }
}
