# CSI SMB/CIFS Plugin Controller
#
# This job runs the controller service for the SMB CSI plugin.
# The controller is responsible for managing volumes (create, delete, etc.).
#
# Deploy with: nomad job run cifs-csi-plugin-controller.nomad

job "cifs-csi-plugin-controller" {
  datacenters = ["dc1"]
  type        = "service"

  group "controller" {
    count = 1

    task "plugin" {
      driver = "podman"

      config {
        image = "registry.k8s.io/sig-storage/smbplugin:v1.19.1"

        args = [
          "--v=5",
          "--nodeid=${node.unique.id}",
          "--endpoint=unix:///csi/csi.sock",
          "--drivername=smb.csi.k8s.io",
        ]
      }

      csi_plugin {
        id        = "cifs"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        memory = 128
        cpu    = 256
      }
    }
  }
}
