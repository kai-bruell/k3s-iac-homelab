# Proxmox Variablen
variable "proxmox_endpoint" {
  description = "Proxmox API Endpoint URL"
  type        = string
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
  description = "TLS-Zertifikat nicht verifizieren (fuer self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "proxmox_ssh_host" {
  description = "Proxmox Host IP fuer SSH"
  type        = string
}

# VM Variablen
variable "vm_name" {
  description = "Name der virtuellen Maschine"
  type        = string
}

variable "hostname" {
  description = "NixOS Hostname"
  type        = string
}

variable "vm_id" {
  description = "VM ID in Proxmox"
  type        = number
}

variable "template_vm_id" {
  description = "VM ID des NixOS Base Templates"
  type        = number
  default     = 9100
}

variable "datastore_id" {
  description = "Proxmox Datastore fuer VM Disks"
  type        = string
  default     = "local-zfs"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
}

# VM Specs
variable "vcpu" {
  description = "Anzahl virtueller CPUs"
  type        = number
  default     = 2
}

variable "sockets" {
  description = "Anzahl CPU-Sockets"
  type        = number
  default     = 1
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk Groesse in GB"
  type        = number
  default     = 20
}

variable "numa_enabled" {
  description = "NUMA aktivieren"
  type        = bool
  default     = false
}

# Netzwerk
variable "static_ip" {
  description = "Statische IP-Adresse mit CIDR"
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

# SSH
variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

variable "ssh_private_key_path" {
  description = "Pfad zum privaten SSH-Schluessel"
  type        = string
  default     = "~/.ssh/homelab-dev"
}

# NixOS Flake
variable "nixos_flake_dir" {
  description = "Pfad zum NixOS Flake-Verzeichnis"
  type        = string
  default     = "../../../nixos"
}

variable "nixos_flake_target" {
  description = "Flake-Target fuer nixos-rebuild"
  type        = string
  default     = "base"
}
