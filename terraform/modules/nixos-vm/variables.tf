# Proxmox Variablen
variable "node_name" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "proxmox_ssh_host" {
  description = "Proxmox Host IP fuer SSH (Guest Agent IP-Abfrage via qm guest cmd)"
  type        = string
}

variable "vm_id" {
  description = "VM ID in Proxmox (muss eindeutig sein)"
  type        = number
}

variable "template_vm_id" {
  description = "VM ID des NixOS Base Templates"
  type        = number
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

# VM Variablen
variable "vm_name" {
  description = "Name der virtuellen Maschine"
  type        = string
}

variable "hostname" {
  description = "NixOS Hostname (wird in host-params.nix gesetzt)"
  type        = string
}

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
  description = "NUMA aktivieren (fuer groessere VMs empfohlen)"
  type        = bool
  default     = false
}

# Netzwerk (statische IP)
variable "network_interface" {
  description = "Name des Netzwerk-Interfaces in der VM (z.B. enp6s18, ens18, eth0)"
  type        = string
  default     = "enp6s18"
}

variable "static_ip" {
  description = "Statische IP-Adresse mit CIDR (z.B. 192.168.178.60/24)"
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
  description = "Pfad zum privaten SSH-Schluessel fuer Provisioning"
  type        = string
  default     = "~/.ssh/homelab-dev"
}

# NixOS Flake
variable "nixos_flake_dir" {
  description = "Pfad zum lokalen NixOS Flake-Verzeichnis"
  type        = string
}

variable "nixos_flake_target" {
  description = "Flake-Target fuer nixos-rebuild (z.B. 'base')"
  type        = string
}
