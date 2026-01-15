# Proxmox Variablen
variable "proxmox_endpoint" {
  description = "Proxmox API Endpoint URL"
  type        = string
  default     = "https://192.168.1.99:8006"
}

variable "proxmox_username" {
  description = "Proxmox Username (z.B. root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox Password"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "TLS-Zertifikat nicht verifizieren (für self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "flatcar_template_id" {
  description = "VM ID des Flatcar Templates in Proxmox"
  type        = number
}

variable "vm_id_start" {
  description = "Start-ID für k3s VMs"
  type        = number
  default     = 200
}

variable "datastore_id" {
  description = "Proxmox Datastore für VM Disks"
  type        = string
  default     = "local-zfs"
}

variable "snippets_datastore" {
  description = "Proxmox Datastore für Snippets (Ignition Configs)"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
}

# Cluster Variablen
variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
  default     = "k3s-dev"
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

variable "server_disk_size" {
  description = "Disk Größe in GB pro Server Node"
  type        = number
  default     = 20
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

variable "agent_disk_size" {
  description = "Disk Größe in GB pro Agent Node"
  type        = number
  default     = 20
}

variable "agent_butane_config_path" {
  description = "Pfad zur Butane Config für Agent Nodes"
  type        = string
  default     = "../../../butane-configs/k3s-agent/config.yaml"
}

# Netzwerk (statische IPs)
variable "server_ips" {
  description = "Liste der statischen IPs für Server Nodes (mit CIDR)"
  type        = list(string)
  default     = ["192.168.1.100/24"]
}

variable "agent_ips" {
  description = "Liste der statischen IPs für Agent Nodes (mit CIDR)"
  type        = list(string)
  default     = ["192.168.1.101/24", "192.168.1.102/24"]
}

variable "gateway" {
  description = "Gateway IP-Adresse"
  type        = string
  default     = "192.168.1.1"
}

variable "dns" {
  description = "DNS Server IP-Adresse"
  type        = string
  default     = "192.168.1.1"
}

# k3s
variable "k3s_token" {
  description = "k3s Cluster Token (wird generiert falls leer)"
  type        = string
  default     = ""
  sensitive   = true
}

# FluxCD / GitHub
variable "github_owner" {
  description = "GitHub Username oder Organisation"
  type        = string
}

variable "github_repository" {
  description = "GitHub Repository Name"
  type        = string
}

variable "github_branch" {
  description = "GitHub Branch"
  type        = string
  default     = "main"
}
