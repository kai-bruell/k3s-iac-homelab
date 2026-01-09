variable "libvirt_uri" {
  description = "libvirt Connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
  default     = "k3s-dev"
}

variable "base_image_path" {
  description = "Pfad zum Flatcar Base Image"
  type        = string
}

variable "pool_path" {
  description = "Pfad zum libvirt Storage Pool"
  type        = string
  default     = "/var/lib/libvirt/images"
}

variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

# Server Nodes
variable "server_count" {
  description = "Anzahl k3s Server Nodes"
  type        = number
  default     = 1
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
  default     = "../../../butane-configs/k3s-server/config.yaml"
}

# Agent Nodes
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
  default     = "../../../butane-configs/k3s-agent/config.yaml"
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

# k3s
variable "k3s_token" {
  description = "k3s Cluster Token (wird generiert falls leer)"
  type        = string
  default     = ""
  sensitive   = true
}
