variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "jellyfin"
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
  description = "The container image to use for Jellyfin"
  type        = string
  default     = "docker.io/jellyfin/jellyfin:latest"
}

variable "timezone" {
  description = "The timezone for the Jellyfin container"
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

variable "http_port" {
  description = "The HTTP port to expose Jellyfin on"
  type        = number
  default     = 8096
}

variable "discovery_port" {
  description = "The discovery port for Jellyfin"
  type        = number
  default     = 7359
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files"
  type        = string
  default     = "media-drive"
}

variable "config_volume_name" {
  description = "The name of the host volume for Jellyfin configuration"
  type        = string
  default     = "jellyfin-config"
}

variable "cache_volume_name" {
  description = "The name of the host volume for Jellyfin cache"
  type        = string
  default     = "jellyfin-cache"
}

variable "register_consul_service" {
  description = "Register the Jellyfin service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "jellyfin"
}
