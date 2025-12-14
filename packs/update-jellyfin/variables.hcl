variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "update-jellyfin"
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
  description = "Cron schedule for the update job"
  type        = string
  default     = "0 3 * * *"
}

variable "timezone" {
  description = "The timezone for the cron schedule"
  type        = string
  default     = "America/New_York"
}

variable "image" {
  description = "The container image to use for the update task"
  type        = string
  default     = "docker.io/debian:bookworm-slim"
}

variable "nomad_variable_path" {
  description = "The Nomad variable path to store the version"
  type        = string
  default     = "nomad/jobs/jellyfin"
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 200
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 256
}
