job "blog" {
  region      = "global"
  datacenters = ["dc1"]
  type = "service"

  # Force deployment
  meta {
    uuid = uuidv4()
  }

  group "blog" {
    count = 1

    network {
      port "http" {
        static = 8000
      }
    }

    ephemeral_disk {
      size = 128
    }

    task "mkdocs" {
      driver = "docker"

      resources {
        cpu = 128
        memory = 256
      }

      config {
        image = "jgroot/mkdocs-blog:local"
        ports = ["http"]
      }

      service {
        name = "mkdocs-blog"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.blog.rule=PathPrefix(`/blog/`)",
        ]

#        check {
#          name     = "mkdocs HTTP port alive"
#          type     = "http"
#          path     = "/"
#          interval = "10s"
#          timeout  = "2s"
#          check_restart {
#            limit = 2
#            grace = "60s"
#            ignore_warnings = false
#          }
#        }
      }
    }
  }
}
