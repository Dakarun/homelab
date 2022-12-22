job "redis" {
  region      = "global"
  datacenters = ["dc1"]
  type = "service"

  group "cache" {
    count = 1
    network {
      port "redis" {
        static = 6379
      }
    }

    ephemeral_disk {
      size = 300
    }

    task "redis" {
      driver = "docker"

      resources {
        cpu = 128
        memory = 512
      }

      config {
        image = "redis:7"
      }

      service {
        name = "global-redis-check"
        tags = ["global", "cache"]
        port = "redis"
        provider = "nomad"
      }
    }
  }
}
