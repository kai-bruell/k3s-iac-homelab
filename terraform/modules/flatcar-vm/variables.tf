# Proxmox Variablen
variable "node_name" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "vm_id" {
  description = "VM ID in Proxmox (muss eindeutig sein)"
  type        = number
}

variable "template_vm_id" {
  description = "VM ID des Flatcar Templates"
  type        = number
}

variable "datastore_id" {
  description = "Proxmox Datastore für VM Disks"
  type        = string
  default     = "local-zfs"
}

variable "snippets_datastore" {
  description = "Proxmox Datastore für Snippets (muss snippets unterstützen)"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
}

# VM Variablen
variable "vm_name" {
  description = "Name der virtuellen Maschine"
  type        = string
}

variable "vcpu" {
  description = "Anzahl virtueller CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk Größe in GB"
  type        = number
  default     = 20
}

# Butane/Ignition Variablen
variable "butane_config_path" {
  description = "Pfad zur Butane Config Template-Datei"
  type        = string
}

variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

variable "extra_butane_config" {
  description = "Zusätzliche Butane Config (YAML)"
  type        = string
  default     = ""
}

# k3s-spezifische Variablen
variable "k3s_role" {
  description = "k3s Rolle (server oder agent)"
  type        = string
  validation {
    condition     = contains(["server", "agent"], var.k3s_role)
    error_message = "k3s_role muss 'server' oder 'agent' sein."
  }
}

variable "k3s_token" {
  description = "k3s Cluster Token"
  type        = string
  sensitive   = true
}

variable "k3s_server_url" {
  description = "k3s Server URL (nur für Agents)"
  type        = string
  default     = ""
}

# Netzwerk (statische IP)
variable "static_ip" {
  description = "Statische IP-Adresse mit CIDR (z.B. 192.168.1.100/24)"
  type        = string
}

variable "gateway" {
  description = "Gateway IP-Adresse"
  type        = string
}

variable "dns" {
  description = "DNS Server IP-Adresse"
  type        = string
}
