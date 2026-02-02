# Proxmox Verbindung
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
  description = "TLS-Zertifikat nicht verifizieren"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name des Proxmox Nodes"
  type        = string
}

# Template (von build-image.sh erstellt)
variable "template_vm_id" {
  description = "VM ID des NixOS-Templates in Proxmox"
  type        = number
}

# VM Konfiguration
variable "vm_name" {
  description = "Name der VM"
  type        = string
  default     = "video-editing"
}

variable "vm_id" {
  description = "VM ID in Proxmox"
  type        = number
  default     = 300
}

variable "cpu_cores" {
  description = "Anzahl CPU Kerne"
  type        = number
  default     = 4
}

variable "memory_mb" {
  description = "RAM in MB"
  type        = number
  default     = 8192
}

variable "disk_size_gb" {
  description = "Boot Disk Groesse in GB"
  type        = number
  default     = 50
}

variable "datastore_id" {
  description = "Proxmox Datastore fuer VM Disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
}

# VGA Konfiguration
variable "vga_type" {
  description = "VGA Type (std, qxl, virtio, none fuer GPU Passthrough)"
  type        = string
  default     = "qxl"
}

variable "vga_memory" {
  description = "VGA Memory in MB"
  type        = number
  default     = 64
}

# GPU Passthrough
variable "gpu_passthrough_enabled" {
  description = "GPU Passthrough aktivieren"
  type        = bool
  default     = false
}

variable "gpu_pci_id" {
  description = "PCI ID der GPU (z.B. 0000:81:00.0)"
  type        = string
  default     = "0000:81:00.0"
}

variable "gpu_audio_pci_id" {
  description = "PCI ID des GPU Audio Controllers (z.B. 0000:81:00.1)"
  type        = string
  default     = "0000:81:00.1"
}
