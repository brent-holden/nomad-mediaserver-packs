variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "tracearr"
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
  description = "The container image to use for Tracearr"
  type        = string
  default     = "ghcr.io/connorgallopo/tracearr:latest"
}

variable "postgres_image" {
  description = "The TimescaleDB container image (pinned; major PostgreSQL upgrades require a dump/restore)"
  type        = string
  default     = "docker.io/timescale/timescaledb-ha:pg18.4-ts2.29.1"
}

variable "redis_image" {
  description = "The Redis container image"
  type        = string
  default     = "docker.io/library/redis:8-alpine"
}

variable "timezone" {
  description = "The timezone for the Tracearr containers"
  type        = string
  default     = "America/New_York"
}

variable "log_level" {
  description = "Tracearr log level (debug, info, warn, error)"
  type        = string
  default     = "info"
}

variable "cpu" {
  description = "The CPU resources to allocate to Tracearr (MHz)"
  type        = number
  default     = 1000
}

variable "memory" {
  description = "The memory resources to allocate to Tracearr (MB)"
  type        = number
  default     = 1024
}

variable "postgres_cpu" {
  description = "The CPU resources to allocate to TimescaleDB (MHz)"
  type        = number
  default     = 1000
}

variable "postgres_memory" {
  description = "The memory resources to allocate to TimescaleDB (MB)"
  type        = number
  default     = 1536
}

variable "port" {
  description = "The port to expose Tracearr on"
  type        = number
  default     = 3005
}

variable "postgres_port" {
  description = "The port TimescaleDB listens on (bound to 127.0.0.1)"
  type        = number
  default     = 5434
}

variable "redis_port" {
  description = "The port Redis listens on (bound to 127.0.0.1)"
  type        = number
  default     = 6381
}

variable "config_volume_name" {
  description = "The name of the host volume for Tracearr data (image cache)"
  type        = string
  default     = "tracearr-config"
}

variable "postgres_volume_name" {
  description = "The name of the host volume for TimescaleDB data"
  type        = string
  default     = "tracearr-postgres"
}

variable "redis_volume_name" {
  description = "The name of the host volume for Redis data"
  type        = string
  default     = "tracearr-redis"
}

variable "secrets_variable_path" {
  description = "Nomad variable path holding jwt_secret, cookie_secret, and db_password"
  type        = string
  default     = "nomad/jobs/tracearr/tracearr"
}

variable "register_consul_service" {
  description = "Register the Tracearr service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "tracearr"
}

# Backup job configuration
variable "enable_backup" {
  description = "Enable periodic backup job for the Tracearr database"
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
  description = "Enable parameterized restore job for the Tracearr database"
  type        = bool
  default     = false
}

# Update job configuration
variable "enable_update" {
  description = "Enable periodic job to fetch latest Tracearr version"
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
  default     = "nomad/jobs/tracearr"
}
