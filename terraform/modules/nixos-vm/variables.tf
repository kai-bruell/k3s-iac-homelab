# --- Proxmox ---

variable "node_name" {
  description = "Name des Proxmox Nodes"
  type        = string
}

variable "vm_id" {
  description = "VM ID in Proxmox (muss eindeutig sein)"
  type        = number
}

variable "bootstrap_template_id" {
  description = "VM ID des Debian cloud-init Bootstrap-Templates (einmalig manuell erstellt, z.B. 9000)"
  type        = number
  default     = 9000
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

# --- VM Specs ---

variable "vm_name" {
  description = "Name der virtuellen Maschine in Proxmox"
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
  description = "Disk Groesse in GB (muss >= der in disko.nix definierten Partitionen sein)"
  type        = number
  default     = 20
}

# --- SSH ---

variable "ssh_public_keys" {
  description = "Liste von SSH Public Keys fuer cloud-init (Bootstrap-Phase)"
  type        = list(string)
}

variable "ssh_private_key_path" {
  description = "Pfad zum privaten SSH-Schluessel fuer nixos-anywhere (muss zum public key passen)"
  type        = string
  default     = "~/.ssh/homelab-dev"
}

# --- NixOS ---

variable "nixos_system_attr" {
  description = "Flake-Attribut des NixOS-Systems (z.B. '.#nixos-minimal'). Muss in nixos/flake.nix definiert sein."
  type        = string
  default     = ".#nixos-minimal"
}
