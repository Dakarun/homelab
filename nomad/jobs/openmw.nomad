job "openmw" {
  region      = "global"
  datacenters = ["dc1"]
  type = "service"

  group "openmw" {
    count = 1

    volume "openmw" {
      type = "host"
      source = "openmw"
      read_only = false
    }

    network {
      port "openmw" {
        static = 25565
      }
    }

    task "openmw" {
      driver = "docker"

      env {
        TES3MP_SERVER_MAXIMUM_PLAYERS = 8
        TES3MP_SERVER_HOSTNAME = "Daka's test server"
        TES3MP_SERVER_PASSWORD = "banana"
      }

      volume_mount {
        volume = "openmw"
        destination = "/server/data"
        read_only = false
      }

      resources {
        cpu = 2048
        memory = 4096
      }

      config {
        image = "tes3mp/server:0.8.1"
        ports = ["openmw"]
      }

      service {
        name = "openmw"
        port = "openmw"
        tags = [
        "traefik.enable=true",
        "traefik.udp.routers.openmw.entrypoints=openmw",
        "traefik.udp.routers.openmw.service=openmw",
        ]
      }
    }
  }
}
