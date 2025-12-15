# CSI SMB/CIFS Plugin Node
#
# This job runs the node service for the SMB CSI plugin.
# The node plugin is responsible for mounting volumes on the host.
#
# Deploy with: nomad job run cifs-csi-plugin-node.nomad

job "cifs-csi-plugin-node" {
  datacenters = ["dc1"]
  type        = "system"

  group "nodes" {
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

        privileged   = true
        network_mode = "host"
      }

      csi_plugin {
        id                     = "cifs"
        type                   = "node"
        mount_dir              = "/csi"
        stage_publish_base_dir = "/local/csi"
      }

      resources {
        cpu    = 256
        memory = 128
      }
    }
  }
}
