terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13"
    }
  }
}

# Butane Config zu Ignition konvertieren
data "ct_config" "vm_config" {
  content = templatefile(var.butane_config_path, {
    hostname       = var.vm_name
    ssh_keys       = jsonencode(var.ssh_keys)
    k3s_role       = var.k3s_role
    k3s_token      = var.k3s_token
    k3s_server_url = var.k3s_server_url
    extra_config   = var.extra_butane_config
    static_ip      = var.static_ip
    gateway        = var.gateway
    dns            = var.dns
  })
  strict = true
}

# Ignition Config als Proxmox Snippet speichern
resource "proxmox_virtual_environment_file" "ignition" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.node_name

  source_raw {
    data      = data.ct_config.vm_config.rendered
    file_name = "${var.vm_name}-ignition.json"
  }
}

# Virtuelle Maschine
resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  # Ignition via QEMU fw_cfg
  kvm_arguments = "-fw_cfg name=opt/org.flatcar-linux/config,file=/var/lib/vz/snippets/${var.vm_name}-ignition.json"

  cpu {
    cores = var.vcpu
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  # Boot-Disk von Flatcar Template klonen
  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
  }

  # Serial Console für Flatcar
  serial_device {}

  operating_system {
    type = "l26"
  }

  agent {
    enabled = false
  }

  # VM neu erstellen wenn Ignition sich ändert (Immutable Infrastructure)
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_file.ignition
    ]
  }
}
