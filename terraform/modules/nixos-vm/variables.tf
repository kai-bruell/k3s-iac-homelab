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

variable "snippet_datastore_id" {
  description = "Proxmox Datastore fuer cloud-init Snippets (muss Snippet-Content aktiviert haben: pvesm set <id> --content snippets,...)"
  type        = string
  default     = "local"
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

variable "nixos_flake_ref" {
  description = "Flake-Referenz fuer nixos-anywhere. Format: <pfad>#<nixosConfigurations-attr>. Pfad relativ zum Verzeichnis von `tofu apply`."
  type        = string
  # Relativ zu terraform/environments/<env>/ -> nixos/
  default     = "../../../nixos#nixos-minimal"
}

# --- GPU Passthrough (optional) ---

variable "bios" {
  description = "BIOS-Typ: 'seabios' (Standard) oder 'ovmf' (UEFI, fuer GPU-Passthrough)"
  type        = string
  default     = "seabios"
}

variable "machine_type" {
  description = "QEMU Machine-Typ (z.B. 'q35'). null = Template-Default."
  type        = string
  default     = null
}

variable "efi_disk_datastore" {
  description = "Datastore fuer EFI-Disk (nur bei bios=ovmf benoetigt). null = keine EFI-Disk."
  type        = string
  default     = null
}

variable "hostpci_id" {
  description = "Host-PCI-ID fuer GPU-Passthrough (z.B. '0000:81:00'). null = kein Passthrough."
  type        = string
  default     = null
}

