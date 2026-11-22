id        = "media-drive"
name      = "media-drive"
type      = "csi"
plugin_id = "cifs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "cifs"
  # cache=none is REQUIRED: the elrepo mainline kernel's (7.3.4) CIFS page-cache
# writeback path is broken - buffered writes >300MB to this share fail with
# EFAULT ("Bad address"), which destroyed files during FileFlows replaces on
# 2026-11-21. Direct writes bypass the bug and sustain ~800MB/s (verified 42GB).
  mount_flags = ["uid=1002", "gid=1001", "file_mode=0644", "dir_mode=0755", "vers=3.0", "cache=none"]
}

secrets {
  username = "plex"
  password = "<REPLACE-WITH-PASSWORD>"
}

context {
  source = "//10.100.0.1/media"
}
