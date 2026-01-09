terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13"
    }
  }
}

# VM-spezifisches Volume (basierend auf übergebenem Base-Image)
resource "libvirt_volume" "vm" {
  name           = "${var.vm_name}-${substr(md5(libvirt_ignition.ignition.id), 0, 8)}.qcow2"
  base_volume_id = var.base_volume_id
  pool           = var.pool_name
  format         = "qcow2"
}

# Ignition-Konfiguration aus Butane generieren
resource "libvirt_ignition" "ignition" {
  name    = "${var.vm_name}-ignition"
  content = data.ct_config.vm_config.rendered
  pool    = var.pool_name
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
  })
  strict = true
}

# Virtuelle Maschine
resource "libvirt_domain" "vm" {
  name   = var.vm_name
  vcpu   = var.vcpu
  memory = var.memory

  coreos_ignition = libvirt_ignition.ignition.id

  disk {
    volume_id = libvirt_volume.vm.id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = var.graphics_type
    listen_type = "address"
  }
}
