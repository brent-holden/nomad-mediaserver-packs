variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "plex"
}

variable "datacenters" {
  description = "A list of datacenters in the region which are eligible for task placement"
  type        = list(string)
  default     = ["dc1"]
}

variable "region" {
  description = "The region where the job should be placed"
  type        = string
  default     = "global"
}

variable "namespace" {
  description = "The namespace where the job should be placed"
  type        = string
  default     = "default"
}

variable "image" {
  description = "The container image to use for Plex"
  type        = string
  default     = "docker.io/plexinc/pms-docker:latest"
}

variable "gpu_transcoding" {
  description = "Enable GPU passthrough for hardware transcoding (requires /dev/dri on host)"
  type        = bool
  default     = true
}

variable "plex_uid" {
  description = "The UID for the Plex user inside the container"
  type        = number
  default     = 1002
}

variable "plex_gid" {
  description = "The GID for the Plex group inside the container"
  type        = number
  default     = 1001
}

variable "timezone" {
  description = "The timezone for the Plex container"
  type        = string
  default     = "America/New_York"
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 16000
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 16384
}

variable "port" {
  description = "The port to expose Plex on"
  type        = number
  default     = 32400
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files"
  type        = string
  default     = "media-drive"
}

variable "config_volume_name" {
  description = "The name of the host volume for Plex configuration"
  type        = string
  default     = "plex-config"
}

variable "transcode_volume_name" {
  description = "The name of the host volume for Plex transcoding"
  type        = string
  default     = "plex-transcode"
}

variable "register_consul_service" {
  description = "Register the Plex service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "plex"
}
