variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "overseerr"
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
  description = "The container image to use for Overseerr"
  type        = string
  default     = "docker.io/linuxserver/overseerr:latest"
}

variable "overseerr_uid" {
  description = "The UID for the Overseerr user inside the container (PUID)"
  type        = number
  default     = 1002
}

variable "overseerr_gid" {
  description = "The GID for the Overseerr group inside the container (PGID)"
  type        = number
  default     = 1001
}

variable "timezone" {
  description = "The timezone for the Overseerr container"
  type        = string
  default     = "America/New_York"
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 1000
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 1024
}

variable "port" {
  description = "The port to expose Overseerr on"
  type        = number
  default     = 5055
}

variable "config_volume_name" {
  description = "The name of the host volume for Overseerr configuration"
  type        = string
  default     = "overseerr-config"
}

variable "register_consul_service" {
  description = "Register the Overseerr service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "overseerr"
}

variable "enable_backup" {
  description = "Enable periodic backup job for Overseerr configuration"
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

variable "enable_restore" {
  description = "Enable parameterized restore job for Overseerr configuration"
  type        = bool
  default     = false
}

variable "enable_update" {
  description = "Enable periodic job to fetch latest Overseerr version"
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
  default     = "nomad/jobs/overseerr"
}
