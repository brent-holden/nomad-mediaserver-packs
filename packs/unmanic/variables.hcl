variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "unmanic"
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
  description = "The container image to use for Unmanic"
  type        = string
  default     = "docker.io/josh5/unmanic:latest"
}

variable "gpu_transcoding" {
  description = "Enable GPU passthrough for hardware transcoding (Intel Arc B580 via stable PCI path)"
  type        = bool
  default     = true
}

variable "gpu_devices" {
  description = "List of GPU device mappings to pass through (host:container format)"
  type        = list(string)
  default     = ["/dev/dri/arc-b580", "/dev/dri/arc-b580-render"]
}

variable "unmanic_uid" {
  description = "The UID for the Unmanic user inside the container (PUID)"
  type        = number
  default     = 1002
}

variable "unmanic_gid" {
  description = "The GID for the Unmanic group inside the container (PGID)"
  type        = number
  default     = 1001
}

variable "timezone" {
  description = "The timezone for the Unmanic container"
  type        = string
  default     = "America/New_York"
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 4000
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 32768
}

variable "port" {
  description = "The port to expose Unmanic on"
  type        = number
  default     = 8888
}

variable "config_volume_name" {
  description = "The name of the host volume for Unmanic configuration"
  type        = string
  default     = "unmanic-config"
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files"
  type        = string
  default     = "media-drive"
}

variable "cache_path" {
  description = "Host path for Unmanic's temporary encoding cache"
  type        = string
  default     = "/var/cache/unmanic"
}

# Backup job configuration
variable "enable_backup" {
  description = "Enable periodic backup job for Unmanic configuration"
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

# Restore job configuration
variable "enable_restore" {
  description = "Enable parameterized restore job for Unmanic configuration"
  type        = bool
  default     = false
}

# Update job configuration
variable "enable_update" {
  description = "Enable periodic job to fetch latest Unmanic version"
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
  default     = "nomad/jobs/unmanic"
}

variable "register_consul_service" {
  description = "Register the Unmanic service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "unmanic"
}

variable "use_tmpfs_cache" {
  description = "Use tmpfs for the transcode cache instead of a host bind mount. Prevents XFS journal hangs if the container is killed mid-transcode."
  type        = bool
  default     = true
}
