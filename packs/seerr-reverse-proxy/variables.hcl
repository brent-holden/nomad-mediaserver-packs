variable "job_name" {
  description = "The name to use for the job"
  type        = string
  default     = "seerr-reverse-proxy"
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
  description = "The container image to use for Caddy"
  type        = string
  default     = "docker.io/library/caddy:alpine"
}

variable "dns_name" {
  description = "The DNS name for the reverse proxy (required for HTTPS)"
  type        = string
  # No default - user must provide this
}

variable "upstream_address" {
  description = "The address of the upstream Seerr service"
  type        = string
  default     = "localhost"
}

variable "upstream_port" {
  description = "The port of the upstream Seerr service"
  type        = number
  default     = 5055
}

variable "http_port" {
  description = "The HTTP port for Caddy (used for HTTPS redirect)"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "The HTTPS port for Caddy"
  type        = number
  default     = 443
}

variable "cpu" {
  description = "The CPU resources to allocate (MHz)"
  type        = number
  default     = 200
}

variable "memory" {
  description = "The memory resources to allocate (MB)"
  type        = number
  default     = 128
}

variable "register_consul_service" {
  description = "Register the reverse proxy service with Consul"
  type        = bool
  default     = true
}

variable "consul_service_name" {
  description = "The name to register with Consul"
  type        = string
  default     = "seerr-proxy"
}

variable "config_volume_name" {
  description = "The name of the Seerr config host volume (used to co-locate with Seerr)"
  type        = string
  default     = "seerr-config"
}
