variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "backup-plex"
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

variable "cron_schedule" {
  description = "Cron schedule for the backup job"
  type        = string
  default     = "0 2 * * *"
}

variable "timezone" {
  description = "The timezone for the cron schedule"
  type        = string
  default     = "America/New_York"
}

variable "image" {
  description = "The container image to use for the backup task"
  type        = string
  default     = "docker.io/debian:bookworm-slim"
}

variable "config_volume_name" {
  description = "The name of the host volume for Plex configuration"
  type        = string
  default     = "plex-config"
}

variable "backup_volume_name" {
  description = "The name of the CSI volume for backups"
  type        = string
  default     = "backup-drive"
}

variable "retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 14
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 500
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 512
}
