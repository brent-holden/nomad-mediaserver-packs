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

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 0
      unlimited      = true
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "1h"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "port" . ]]
        to     = [[ var "port" . ]]
      }
    }

[[ if var "register_consul_service" . ]]
    service {
      name     = "[[ var "consul_service_name" . ]]"
      port     = "http"
      provider = "consul"

      check {
        name     = "fileflows-ui-alive"
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }
[[ end ]]

    volume "config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-multi-writer"
    }

    volume "media" {
      type            = "csi"
      source          = "[[ var "media_volume_name" . ]]"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "fileflows" {
      driver = "podman"

      config {
        image        = "[[ var "image" . ]]"
        force_pull   = [[ var "force_pull" . ]]
        network_mode = "host"
        ports        = ["http"]

        volumes = [
          "/var/cache/fileflows:/temp",
        ]

        devices = [
[[ range $idx, $dev := var "gpu_devices" . ]]
          "[[ $dev ]]",
[[ end ]]
        ]
      }

      volume_mount {
        volume      = "config"
        destination = "/app/Data"
        read_only   = false
      }

      volume_mount {
        volume      = "media"
        destination = "/media"
        read_only   = false
      }

      template {
        data        = <<EOH
TZ=[[ var "timezone" . ]]
PUID=[[ var "fileflows_uid" . ]]
PGID=[[ var "fileflows_gid" . ]]
EOH
        destination = "local/env_vars"
        env          = true
      }

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }
    }
  }
}
