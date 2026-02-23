# --- Proxmox Provider ---

variable "proxmox_endpoint" {
  description = "Proxmox API Endpoint (z.B. https://192.168.178.10:8006)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox API Benutzer (z.B. root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API Passwort"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "TLS-Verifikation deaktivieren (nur fuer self-signed Zertifikate)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name des Proxmox Nodes (z.B. pve)"
  type        = string
}

# --- VM ---

variable "vm_id" {
  description = "VM ID in Proxmox (muss eindeutig sein)"
  type        = number
}

variable "bootstrap_template_id" {
  description = "VM ID des Debian cloud-init Bootstrap-Templates (einmalig manuell erstellt)"
  type        = number
  default     = 9000
}

variable "snippet_datastore_id" {
  description = "Proxmox Datastore fuer cloud-init Snippets (muss Snippet-Content aktiviert haben)"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge (z.B. vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "vm_name" {
  description = "Name der VM in Proxmox"
  type        = string
  default     = "nixos-example"
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
  description = "Liste von SSH Public Keys fuer Root-Zugang (cloud-init + NixOS authorized_keys)"
  type        = list(string)
}

variable "ssh_private_key_path" {
  description = "Pfad zum privaten SSH-Schluessel fuer nixos-anywhere"
  type        = string
  default     = "~/.ssh/homelab-dev"
}

# --- NixOS ---

variable "nixos_flake_ref" {
  description = "Flake-Referenz fuer nixos-anywhere. Format: <pfad>#<nixosConfigurations-attr>. Pfad relativ zum Verzeichnis von `tofu apply`."
  type        = string
  default     = "../../../nixos#nixos-example"
}
