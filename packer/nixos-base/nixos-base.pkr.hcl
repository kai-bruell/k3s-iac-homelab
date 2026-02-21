packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type    = string
  default = "root@pam"
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_skip_tls_verify" {
  type    = bool
  default = true
}

variable "vm_id" {
  type    = number
  default = 9100
}

variable "iso_url" {
  type    = string
  default = "https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "storage_pool" {
  type    = string
  default = "local-zfs"
}

variable "disk_size" {
  type    = string
  default = "20G"
}

variable "memory" {
  type    = number
  default = 4096
}

variable "cores" {
  type    = number
  default = 4
}

variable "ssh_password" {
  type      = string
  default   = "packer"
  sensitive = true
}

variable "ssh_keys" {
  type    = string
  default = ""
}

variable "build_ip" {
  description = "Temporaere statische IP fuer Packer-Build (muss im Subnetz frei sein)"
  type        = string
  default     = "192.168.178.250"
}

source "proxmox-iso" "nixos-base" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  vm_id       = var.vm_id
  vm_name     = "nixos-base-template"
  template_description = "NixOS Base Template - built by Packer"

  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  os       = "l26"
  machine  = "q35"
  bios     = "ovmf"
  cpu_type = "host"
  cores    = var.cores
  sockets  = 1
  memory   = var.memory

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    type         = "scsi"
    discard      = true
    ssd          = true
  }

  efi_config {
    efi_storage_pool  = var.storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # NixOS Live-ISO: sshd laeuft bereits, PasswordAuth ist an
  # Nur Passwort fuer 'nixos' User setzen + Build-IP hinzufuegen
  # sshd NICHT anfassen (PermitRootLogin=prohibit-password ist NixOS-Default)
  boot_wait = "60s"
  boot_command = [
    "sudo -i<enter><wait3s>",
    "echo nixos:${var.ssh_password} | chpasswd<enter><wait2s>",
    "IFACE=$(ls /sys/class/net | grep -v lo)<enter><wait1s>",
    "ip addr add ${var.build_ip}/24 dev $IFACE<enter><wait2s>"
  ]

  ssh_host     = var.build_ip
  ssh_username = "nixos"
  ssh_password = var.ssh_password
  ssh_timeout  = "15m"
}

build {
  sources = ["source.proxmox-iso.nixos-base"]

  # NixOS installieren (als root via sudo)
  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script = "scripts/install-nixos.sh"
    environment_vars = [
      "SSH_KEYS=${var.ssh_keys}"
    ]
  }

  # Template vorbereiten (Cleanup)
  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script = "scripts/post-install.sh"
  }
}
