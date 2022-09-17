job "postgresql" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "postgresql" {
    count = 1

    network {
      port "db" {
        static = 5432
      }
    }

    volume "postgresql" {
      type = "host"
      source = "postgresql"
      read_only = false
    }

    task "postgresql" {
      driver = "docker"
      resources {
        cpu    = 256
        memory = 256
      }

      env {
        PGDATA = "/postgresql"
      }

      template {
        env = true
        destination = "secrets/postgresql.env"
        data = <<EOH
          {{ with secret "consul/postgresql" }}
          POSTGRES_USER="{{ .Data.data.user }}"
          POSTGRES_PASSWORD="{{ .Data.data.password }}"
          {{ end }}
        EOH
      }

      config {
        image        = "postgres:12"
        network_mode = "host"
      }

      volume_mount {
        volume = "postgresql"
        destination = "/postgresql"
        read_only = false
      }

      service {
        name = "postgresql"
        port = "db"
        check {
          name = "alive"
          type = "tcp"
          interval = "15s"
          timeout = "2s"
        }
      }
    }
  }
}
