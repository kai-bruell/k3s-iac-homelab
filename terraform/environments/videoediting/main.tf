terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
  }
}

# bpg/proxmox Provider
# Docs: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

# NixOS VM Modul
# Flow: Bootstrap-VM (Debian cloud-init) -> nixos-anywhere -> NixOS aus Flake
module "nixos_vm" {
  source = "../../modules/nixos-vm"

  # Proxmox
  node_name             = var.proxmox_node
  vm_id                 = var.vm_id
  bootstrap_template_id = var.bootstrap_template_id
  snippet_datastore_id  = var.snippet_datastore_id
  network_bridge        = var.network_bridge

  # VM Specs
  vm_name = var.vm_name
  vcpu    = var.vcpu
  sockets = var.sockets
  memory  = var.memory

  # SSH
  ssh_public_keys      = var.ssh_public_keys
  ssh_private_key_path = var.ssh_private_key_path

  # NixOS Flake
  nixos_flake_ref = var.nixos_flake_ref

  # GPU Passthrough
  bios               = var.bios
  machine_type       = var.machine_type
  efi_disk_datastore = var.efi_disk_datastore
  hostpci_id         = var.hostpci_id
}
