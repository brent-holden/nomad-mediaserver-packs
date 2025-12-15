variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "sonarr"
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
  description = "The container image to use for Sonarr"
  type        = string
  default     = "docker.io/linuxserver/sonarr:latest"
}

variable "sonarr_uid" {
  description = "The UID for the Sonarr user inside the container (PUID)"
  type        = number
  default     = 1000
}

variable "sonarr_gid" {
  description = "The GID for the Sonarr group inside the container (PGID)"
  type        = number
  default     = 1000
}

variable "timezone" {
  description = "The timezone for the Sonarr container"
  type        = string
  default     = "America/New_York"
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 500
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 1024
}

variable "port" {
  description = "The port to expose Sonarr on"
  type        = number
  default     = 8989
}

variable "config_volume_name" {
  description = "The name of the host volume for Sonarr configuration"
  type        = string
  default     = "sonarr-config"
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files"
  type        = string
  default     = "media-drive"
}

variable "register_consul_service" {
  description = "Register the Sonarr service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "sonarr"
}

variable "enable_backup" {
  description = "Enable periodic backup job for Sonarr configuration"
  type        = bool
  default     = true
}

variable "backup_cron_schedule" {
  description = "Cron schedule for the backup job"
  type        = string
  default     = "0 2 * * *"
}

variable "backup_volume_name" {
  description = "The name of the CSI volume for backups"
  type        = string
  default     = "backup-drive"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 14
}

variable "enable_update" {
  description = "Enable periodic job to fetch latest Sonarr version"
  type        = bool
  default     = true
}

variable "update_cron_schedule" {
  description = "Cron schedule for the update job"
  type        = string
  default     = "0 3 * * *"
}

variable "nomad_variable_path" {
  description = "The Nomad variable path to store the version"
  type        = string
  default     = "nomad/jobs/sonarr"
}
