variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "fileflows"
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
  description = "The container image to use for FileFlows (pin to a numeric tag, e.g. 26.10 - never :latest, upgrades must be deliberate)"
  type        = string
  default     = "docker.io/revenz/fileflows:26.10"
}

variable "gpu_transcoding" {
  description = "Enable GPU passthrough for hardware transcoding (Intel B580 on /dev/dri/card1)"
  type        = bool
  default     = true
}

variable "gpu_devices" {
  description = "List of GPU device mappings to pass through (host:container format)"
  type        = list(string)
  default     = ["/dev/dri/card1:/dev/dri/card1", "/dev/dri/renderD129:/dev/dri/renderD129"]
}

variable "fileflows_uid" {
  description = "The UID for the FileFlows user inside the container (PUID)"
  type        = number
  default     = 1002
}

variable "fileflows_gid" {
  description = "The GID for the FileFlows group inside the container (PGID)"
  type        = number
  default     = 1001
}

variable "timezone" {
  description = "The timezone for the FileFlows container"
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
  default     = 4096
}

variable "port" {
  description = "The port to expose FileFlows on"
  type        = number
  default     = 5000
}

variable "config_volume_name" {
  description = "The name of the host volume for FileFlows configuration"
  type        = string
  default     = "fileflows-config"
}

variable "media_volume_name" {
  description = "The name of the CSI volume for media files"
  type        = string
  default     = "media-drive"
}

variable "temp_path" {
  description = "Host path for FileFlows temporary processing cache"
  type        = string
  default     = "/var/cache/fileflows"
}

# Backup job configuration
variable "enable_backup" {
  description = "Enable periodic backup job for FileFlows configuration"
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
  description = "Enable parameterized restore job for FileFlows configuration"
  type        = bool
  default     = false
}

# Update job configuration
variable "enable_update" {
  description = "Enable periodic job to fetch latest FileFlows version"
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
  default     = "nomad/jobs/fileflows"
}

variable "register_consul_service" {
  description = "Register the FileFlows service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "fileflows"
}

variable "force_pull" {
  description = "Always pull the image on task start (leave false so restarts never silently upgrade a pinned tag)"
  type        = bool
  default     = false
}

variable "node_hostnames" {
  description = "Hostnames allowed for placement (must have the config host volume and GPU devices)"
  type        = list(string)
  default     = ["polaris.lan.eventide.network"]
}

# Update job behavior
variable "auto_apply_update" {
  description = "Automatically re-submit the fileflows job with the newest image tag when one is found. If false, the new version is only recorded in the Nomad variable (apply it manually by re-deploying the pack with the new image tag)."
  type        = bool
  default     = false
}

# Health job configuration
variable "enable_health" {
  description = "Enable periodic health check job that detects the FileFlows broken-processing failure mode (failed DockerMods halting all processing, auto-disabled libraries, stale queue)"
  type        = bool
  default     = true
}

variable "health_cron_schedule" {
  description = "Cron schedule for the health job"
  type        = string
  default     = "0 */4 * * *"
}

variable "health_expected_libraries" {
  description = "FileFlows libraries expected to be enabled (alerts if FileFlows auto-disables one after processing failures)"
  type        = list(string)
  default     = ["TV", "Movies"]
}

variable "health_stale_hours" {
  description = "Alert if there is an unprocessed backlog, nothing currently processing, and no queue activity for this many hours"
  type        = number
  default     = 48
}

variable "health_webhook_url" {
  description = "Optional webhook (e.g. Gotify/Discord) POSTed to when a health check fails (empty = only fail the Nomad job)"
  type        = string
  default     = ""
}
