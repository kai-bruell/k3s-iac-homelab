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

resource "proxmox_virtual_environment_vm" "video_editing" {
  name      = var.vm_name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  description = "Video Editing Workstation - NixOS with NVIDIA 470 Legacy Driver"
  tags        = ["video-editing", "nixos", "workstation"]

  # Clone from NixOS template (built via build-image.sh)
  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  # CPU
  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  # RAM
  memory {
    dedicated = var.memory_mb
  }

  # Disk kommt vom Template (virtio0), keine extra Disk erstellen
  # Boot-Reihenfolge setzen
  boot_order = ["virtio0"]

  # Netzwerk
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # VGA fuer Desktop-Nutzung (deaktiviert bei GPU Passthrough)
  dynamic "vga" {
    for_each = var.vga_type != "none" ? [1] : []
    content {
      type   = var.vga_type
      memory = var.vga_memory
    }
  }

  # NVIDIA GPU Passthrough
  dynamic "hostpci" {
    for_each = var.gpu_passthrough_enabled ? [1] : []
    content {
      device = "hostpci0"
      id     = var.gpu_pci_id
      pcie   = true
      rombar = true
    }
  }

  # GPU Audio wird automatisch mit durchgereicht (Multifunction Device)

  # Agent
  agent {
    enabled = true
  }

  # q35 Machine Type fuer PCIe Passthrough
  machine = "q35"

  operating_system {
    type = "l26"
  }
}
