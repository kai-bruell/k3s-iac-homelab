variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
}

# Proxmox Variablen
variable "node_name" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "template_vm_id" {
  description = "VM ID des Flatcar Templates"
  type        = number
}

variable "vm_id_start" {
  description = "Start-ID für VMs (Server: start, start+1, ...; Agents: start+server_count, ...)"
  type        = number
  default     = 200
}

variable "datastore_id" {
  description = "Proxmox Datastore für VM Disks"
  type        = string
  default     = "local-zfs"
}

variable "snippets_datastore" {
  description = "Proxmox Datastore für Snippets"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
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

variable "server_disk_size" {
  description = "Disk Größe in GB pro Server Node"
  type        = number
  default     = 20
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

variable "agent_disk_size" {
  description = "Disk Größe in GB pro Agent Node"
  type        = number
  default     = 20
}

variable "agent_butane_config_path" {
  description = "Pfad zur Butane Config für Agent Nodes"
  type        = string
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

# Netzwerk (statische IPs)
variable "server_ips" {
  description = "Liste der statischen IPs für Server Nodes (mit CIDR, z.B. 192.168.1.100/24)"
  type        = list(string)
}

variable "agent_ips" {
  description = "Liste der statischen IPs für Agent Nodes (mit CIDR, z.B. 192.168.1.101/24)"
  type        = list(string)
}

variable "gateway" {
  description = "Gateway IP-Adresse"
  type        = string
}

variable "dns" {
  description = "DNS Server IP-Adresse"
  type        = string
}
