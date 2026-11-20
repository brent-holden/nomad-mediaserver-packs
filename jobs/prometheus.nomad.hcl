job "prometheus" {
  region      = "global"
  datacenters = ["dc1"]
  namespace   = "default"
  type        = "service"

  group "prometheus" {
    count = 1

    volume "prometheus-config" {
      type            = "host"
      source          = "prometheus-config"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
    }

    network {
      mode = "host"
      port "http" {
        static = 9091
      }
    }

    task "prometheus" {
      driver = "podman"

      constraint {
        attribute = "${attr.consul.version}"
        operator  = "semver"
        value     = ">= 1.8.0"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      config {
        image        = "docker.io/prom/prometheus:latest"
        network_mode = "host"
        ports        = ["http"]
        volumes      = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
        ]
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=30d",
          "--web.listen-address=0.0.0.0:9091",
          "--web.enable-lifecycle",
        ]
      }

      volume_mount {
        volume      = "prometheus-config"
        destination = "/prometheus"
      }

      template {
        data = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # ---------------------------------------------------------------
  # Infrastructure: Nomad
  # ---------------------------------------------------------------
  - job_name: "nomad"
    metrics_path: "/v1/metrics"
    params:
      format: ["prometheus"]
    consul_sd_configs:
      - server: "localhost:8500"
        services: ["nomad-client"]
      - server: "localhost:8500"
        services: ["nomad"]
        tags: ["http"]
    relabel_configs:
      - source_labels: [__meta_consul_node]
        regex: "(.+?)\\..*"
        target_label: node
        replacement: "$${1}"
      - source_labels: [__meta_consul_service]
        regex: "nomad-client"
        target_label: role
        replacement: "client"
      - source_labels: [__meta_consul_service]
        regex: "nomad"
        target_label: role
        replacement: "server"

  # ---------------------------------------------------------------
  # Infrastructure: Consul
  # ---------------------------------------------------------------
  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
    consul_sd_configs:
      - server: "localhost:8500"
        services: ["nomad-client"]
      - server: "localhost:8500"
        services: ["consul"]
    relabel_configs:
      - source_labels: [__meta_consul_address]
        target_label: __address__
        replacement: "$${1}:8500"
      - source_labels: [__meta_consul_node]
        regex: "(.+?)\\..*"
        target_label: node
        replacement: "$${1}"
      - source_labels: [__meta_consul_service]
        regex: "nomad-client"
        target_label: role
        replacement: "client"
      - source_labels: [__meta_consul_service]
        regex: "consul"
        target_label: role
        replacement: "server"

  # ---------------------------------------------------------------
  # Exporters: Podman (system job - runs on all nodes)
  # ---------------------------------------------------------------
  - job_name: "podman-exporter"
    consul_sd_configs:
      - server: "localhost:8500"
        services: ["podman-exporter"]
    relabel_configs:
      - source_labels: [__meta_consul_address]
        target_label: __address__
        replacement: "$${1}:9882"
      - source_labels: [__meta_consul_node]
        regex: "(.+?)\\..*"
        target_label: instance
        replacement: "$${1}"

  # ---------------------------------------------------------------
  # Monitoring stack self-monitoring
  # ---------------------------------------------------------------
  - job_name: "prometheus"
    consul_sd_configs:
      - server: "localhost:8500"
        services: ["prometheus"]
    relabel_configs:
      - source_labels: [__meta_consul_address]
        target_label: __address__
        replacement: "$${1}:9091"
      - source_labels: [__meta_consul_node]
        regex: "(.+?)\\..*"
        target_label: instance
        replacement: "$${1}"

  - job_name: "grafana"
    consul_sd_configs:
      - server: "localhost:8500"
        services: ["grafana"]
    relabel_configs:
      - source_labels: [__meta_consul_address]
        target_label: __address__
        replacement: "$${1}:3000"
      - source_labels: [__meta_consul_node]
        regex: "(.+?)\\..*"
        target_label: instance
        replacement: "$${1}"
EOF
        destination = "local/prometheus.yml"
        change_mode = "restart"
      }

      template {
        data        = "TZ=America/New_York"
        destination = "local/env_vars"
        env         = true
      }

      service {
        name     = "prometheus"
        port     = "http"
        provider = "consul"

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
}
