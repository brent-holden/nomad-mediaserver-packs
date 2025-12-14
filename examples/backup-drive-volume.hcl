# Example CSI volume configuration for backup storage
# This requires a CIFS/SMB CSI plugin to be installed on your Nomad cluster
#
# Register with: nomad volume register backup-drive-volume.hcl

id        = "backup-drive"
name      = "backup-drive"
type      = "csi"
plugin_id = "cifs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

context {
  # Replace with your fileserver IP and share path
  source = "//192.168.1.100/backups"
}

# Mount options for CIFS
mount_options {
  fs_type = "cifs"
  # Replace <USERNAME> and <PASSWORD> with your credentials
  # Consider using Nomad variables or Vault for secrets in production
  mount_flags = ["username=<USERNAME>", "password=<PASSWORD>", "uid=1002", "gid=1001", "file_mode=0644", "dir_mode=0755", "vers=3.0"]
}
