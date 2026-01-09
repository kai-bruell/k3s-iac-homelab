variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
}

variable "pool_name" {
  description = "Name des libvirt Storage Pools"
  type        = string
}

variable "base_volume_id" {
  description = "ID des Basis-Image Volumes"
  type        = string
}

variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

# Server-Konfiguration
variable "server_count" {
  description = "Anzahl k3s Server Nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.server_count >= 1 && var.server_count <= 5
    error_message = "server_count muss zwischen 1 und 5 liegen."
  }
}

variable "server_vcpu" {
  description = "vCPUs pro Server Node"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "RAM in MB pro Server Node"
  type        = number
  default     = 4096
}

variable "server_butane_config_path" {
  description = "Pfad zur Butane Config für Server Nodes"
  type        = string
}

# Agent-Konfiguration
variable "agent_count" {
  description = "Anzahl k3s Agent Nodes"
  type        = number
  default     = 2
}

variable "agent_vcpu" {
  description = "vCPUs pro Agent Node"
  type        = number
  default     = 2
}

variable "agent_memory" {
  description = "RAM in MB pro Agent Node"
  type        = number
  default     = 2048
}

variable "agent_butane_config_path" {
  description = "Pfad zur Butane Config für Agent Nodes"
  type        = string
}

# Netzwerk
variable "network_name" {
  description = "Name des libvirt Netzwerks"
  type        = string
  default     = "default"
}

variable "graphics_type" {
  description = "Grafik-Typ (spice oder vnc)"
  type        = string
  default     = "spice"
}

# k3s-Konfiguration
variable "k3s_token" {
  description = "k3s Cluster Token (wird generiert falls leer)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "first_server_extra_config" {
  description = "Zusätzliche Config für ersten Server Node"
  type        = string
  default     = ""
}

variable "server_extra_config" {
  description = "Zusätzliche Config für weitere Server Nodes"
  type        = string
  default     = ""
}

variable "agent_extra_config" {
  description = "Zusätzliche Config für Agent Nodes"
  type        = string
  default     = ""
}
