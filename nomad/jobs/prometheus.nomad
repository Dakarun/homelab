locals {
  dashboards = [
    "node-exporter-full.json",
    "windows-exporter-dashboard.json"
  ]
}

job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "monitoring" {
    count = 1

    volume "prometheus" {
      type = "host"
      source = "prometheus"
      read_only = false
    }

    network {
      port "prometheus_ui" {
        static = 9090
      }
      port "http" {

      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 300
    }

    task "prometheus" {
      volume_mount {
        volume = "prometheus"
        destination = "/prometheus"
        read_only = false
      }

      resources {
        cpu    = 256
        memory = 512
      }

      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:

  - job_name: 'nomad_metrics'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['nomad-client', 'nomad']
    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'desktop_metrics'
    static_configs:
    - targets: ['desktop-hr18u8t:9182']

  - job_name: 'homelab_metrics'
    static_configs:
    - targets: ['homelab-1:9100']

EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        args = [
          "--web.external-url", "/prometheus/",
          "--config.file", "/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path", "/prometheus",
          "--web.console.libraries", "/usr/share/prometheus/console_libraries",
          "--web.console.templates", "/usr/share/prometheus/consoles",
        ]

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml"
        ]

        ports = ["prometheus_ui"]
      }

      service {
        name = "prometheus"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=PathPrefix(`/prometheus/`)",
        ]
        port = "prometheus_ui"

#        check {
#          name     = "prometheus_ui port alive"
#          type     = "http"
#          path     = "/-/prometheus/healthy"
#          interval = "10s"
#          timeout  = "2s"
#        }
      }
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 256
      }

      env {
        GF_PATHS_CONFIG = "/local/grafana/config.ini"
        GF_LOG_MODE = "console"
        GF_SERVER_HTTP_PORT = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }

      template {
        destination = "local/grafana/config.ini"
        data = <<EOH
[server]
domain = homelab-1
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
serve_from_sub_path = true

[auth.anonymous]
enabled = true
org_role = Editor

[auth]
disable_login_form = true

[auth.basic]
enabled = false
EOH
      }

      template {
        destination = "/local/grafana/provisioning/datasources/prometheus.yaml"
        data = <<EOH
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://homelab-1:8080/prometheus
    jsonData:
      exemplarTraceIdDestinations:
      - name: traceID
        datasourceUid: tempo
EOH
      }

      template {
        destination = "/local/grafana/provisioning/dashboards/dashboards.yaml"
        data = <<EOH
apiVersion: 1

providers:
  - name: dashboards
    type: file
    updateIntervalSeconds: 30
    options:
      path: /local/grafana/provisioning/dashboards/
      foldersFromFilesStructure: true
EOH
      }

      # Dashboard setup
      dynamic template {
        for_each = local.dashboards

        content {
          data      = file("resources/grafana/dashboards/${template.value}")
          destination = "/local/grafana/provisioning/dashboards/${template.value}"
          left_delimiter = "{{{{"
          right_delimiter = "}}}}"
        }
      }

      service {
        name = "grafana"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=PathPrefix(`/grafana`)",
        ]
        check {
          name     = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "5s"
          timeout  = "2s"
          check_restart {
            limit = 2
            grace = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}
