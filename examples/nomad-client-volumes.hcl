# Example Nomad client configuration for host volumes
# Add this to your Nomad client configuration file (e.g., /etc/nomad.d/client.hcl)
#
# These host volumes provide persistent storage for application configuration

client {
  enabled = true

  # Plex host volumes
  host_volume "plex-config" {
    path      = "/opt/nomad/volumes/plex-config"
    read_only = false
  }

  host_volume "plex-transcode" {
    path      = "/opt/nomad/volumes/plex-transcode"
    read_only = false
  }

  # Jellyfin host volumes
  host_volume "jellyfin-config" {
    path      = "/opt/nomad/volumes/jellyfin-config"
    read_only = false
  }

  host_volume "jellyfin-cache" {
    path      = "/opt/nomad/volumes/jellyfin-cache"
    read_only = false
  }
}
