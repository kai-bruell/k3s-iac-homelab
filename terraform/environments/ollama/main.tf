terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password

  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

module "nixos_vm" {
  source = "../../modules/nixos-vm"

  # Proxmox
  proxmox_ssh_host = var.proxmox_ssh_host
  node_name        = var.proxmox_node
  vm_id            = var.vm_id
  template_vm_id   = var.template_vm_id
  datastore_id     = var.datastore_id
  network_bridge   = var.network_bridge

  # VM Specs
  vm_name      = var.vm_name
  hostname     = var.hostname
  vcpu         = var.vcpu
  sockets      = var.sockets
  memory       = var.memory
  disk_size    = var.disk_size
  numa_enabled = var.numa_enabled

  # Netzwerk
  static_ip = var.static_ip
  gateway   = var.gateway
  dns       = var.dns

  # SSH
  ssh_keys             = var.ssh_keys
  ssh_private_key_path = var.ssh_private_key_path

  # NixOS Flake
  nixos_flake_dir    = var.nixos_flake_dir
  nixos_flake_target = var.nixos_flake_target
}
