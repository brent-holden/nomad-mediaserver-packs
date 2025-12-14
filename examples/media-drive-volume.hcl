# Example CSI volume configuration for media storage
# This requires a CIFS/SMB CSI plugin to be installed on your Nomad cluster
#
# Register with: nomad volume register media-drive-volume.hcl

id        = "media-drive"
name      = "media-drive"
type      = "csi"
plugin_id = "cifs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

context {
  # Replace with your fileserver IP and share path
  source = "//192.168.1.100/media"
}

# Mount options for CIFS
mount_options {
  fs_type = "cifs"
  # Replace <USERNAME> and <PASSWORD> with your credentials
  # Consider using Nomad variables or Vault for secrets in production
  mount_flags = ["username=<USERNAME>", "password=<PASSWORD>", "uid=1000", "gid=1000", "file_mode=0755", "dir_mode=0755"]
}
