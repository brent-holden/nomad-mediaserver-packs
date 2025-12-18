job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "service"

  group "caddy" {
    count = 1

    # Require the Overseerr config volume to co-locate with Overseerr
    volume "overseerr-config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      read_only       = true
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = [[ var "http_port" . ]]
      }
      port "https" {
        static = [[ var "https_port" . ]]
      }
    }

    task "caddy" {
      driver = "podman"

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      config {
        image        = "[[ var "image" . ]]"
        ports        = ["http", "https"]
        network_mode = "host"
        args         = ["caddy", "run", "--config", "/local/Caddyfile", "--adapter", "caddyfile"]
      }

      template {
        data = <<EOH
[[ var "dns_name" . ]] {
    reverse_proxy [[ var "upstream_address" . ]]:[[ var "upstream_port" . ]]
}
EOH
        destination = "local/Caddyfile"
      }

[[- if var "register_consul_service" . ]]
      service {
        name = "[[ var "consul_service_name" . ]]"
        port = "https"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
[[- end ]]
    }
  }
}
