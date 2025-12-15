variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "radarr"
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
  description = "The container image to use for Radarr"
  type        = string
  default     = "docker.io/linuxserver/radarr:latest"
}

variable "radarr_uid" {
  description = "The UID for the Radarr user inside the container (PUID)"
  type        = number
  default     = 1000
}

variable "radarr_gid" {
  description = "The GID for the Radarr group inside the container (PGID)"
  type        = number
  default     = 1000
}

variable "timezone" {
  description = "The timezone for the Radarr container"
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
  description = "The port to expose Radarr on"
  type        = number
  default     = 7878
}

# Volume configuration
variable "config_volume_name" {
  description = "The name of the host volume for Radarr configuration"
  type        = string
  default     = "radarr-config"
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files (movies)"
  type        = string
  default     = "media-drive"
}

variable "downloads_volume_name" {
  description = "The name of the host volume for downloads"
  type        = string
  default     = "downloads"
}

variable "register_consul_service" {
  description = "Register the Radarr service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "radarr"
}

# Backup job configuration
variable "enable_backup" {
  description = "Enable periodic backup job for Radarr configuration"
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

# Update job configuration
variable "enable_update" {
  description = "Enable periodic job to fetch latest Radarr version"
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
  default     = "nomad/jobs/radarr"
}

# CSI Volume configuration
variable "deploy_csi_volumes" {
  description = "Deploy CSI volumes for media and backup storage"
  type        = bool
  default     = false
}

variable "csi_plugin_id" {
  description = "The CSI plugin ID to use for volumes"
  type        = string
  default     = "cifs"
}

variable "csi_volume_username" {
  description = "Username for CIFS/SMB authentication"
  type        = string
  default     = "radarr"
}

variable "csi_volume_password" {
  description = "Password for CIFS/SMB authentication"
  type        = string
  default     = ""
}

variable "media_volume_source" {
  description = "The CIFS/SMB source path for media volume"
  type        = string
  default     = "//10.100.0.1/media"
}

variable "backup_volume_source" {
  description = "The CIFS/SMB source path for backup volume"
  type        = string
  default     = "//10.100.0.1/backups"
}
