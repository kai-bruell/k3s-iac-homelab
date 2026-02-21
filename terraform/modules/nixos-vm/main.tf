terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# --- VM aus cloud-init Bootstrap-Image erstellen ---
#
# Vorbedingung (einmalige manuelle Einrichtung auf Proxmox):
#   1. Debian Cloud Image herunterladen:
#      wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
#   2. Als Proxmox-Template importieren (Beispiel VM-ID 9000):
#      qm create 9000 --name "debian-cloud-init" --memory 1024 --net0 virtio,bridge=vmbr0
#      qm importdisk 9000 debian-12-genericcloud-amd64.qcow2 local-lvm
#      qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
#      qm set 9000 --boot c --bootdisk scsi0 --ide2 local-lvm:cloudinit
#      qm template 9000
#
# nixos-anywhere verbindet sich per SSH auf dieses Bootstrap-Image,
# bootet via kexec in den NixOS-Installer und installiert das finale System aus dem Flake.
# Das Bootstrap-Image wird dabei komplett ueberschrieben.

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  clone {
    vm_id = var.bootstrap_template_id # Debian cloud-init Template (VM ID 9000)
    full  = true
  }

  cpu {
    cores   = var.vcpu
    sockets = var.sockets
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  # virtio-blk: erscheint als /dev/vda im Gast (passend zu disko.nix)
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # QEMU Guest Agent: Debian genericcloud hat diesen vorinstalliert.
  # bpg/proxmox wartet bis der Agent die IP meldet – dauert ~60-90s (cloud-init laeuft im Hintergrund)
  agent {
    enabled = true
  }

  # Cloud-init: SSH-Key injecten, DHCP
  # Nach nixos-anywhere hat die VM die statische IP aus dem Nix-Flake (default.nix)
  initialization {
    ip_config {
      ipv4 { address = "dhcp" }
    }
    user_account {
      username = "root"
      keys     = var.ssh_public_keys
    }
  }
}

# --- Erste nicht-loopback IPv4 der VM ermitteln ---
# Wird vom QEMU Guest Agent gemeldet sobald cloud-init die Netzwerkkonfiguration abgeschlossen hat
locals {
  vm_ip = [
    for ip in flatten(proxmox_virtual_environment_vm.vm.ipv4_addresses) :
    ip if !startswith(ip, "127.")
  ][0]
}

# --- NixOS via nixos-anywhere CLI installieren ---
#
# Was nixos-anywhere macht:
#   1. Laedt kexec-Tarball auf die Bootstrap-VM (Debian)
#   2. Fuehrt kexec aus: VM bootet in NixOS-Installer (kein Reboot der Hardware)
#   3. Fuehrt disko aus: partitioniert /dev/vda deklarativ (aus Flake)
#   4. Installiert NixOS via nixos-install (Build auf der VM, kein lokales nix build)
#   5. Reboot: VM startet mit finalem NixOS und statischer IP aus dem Flake
#
# Voraussetzung lokal: nixos-anywhere Binary (via devbox bereitgestellt)
# Referenz: https://github.com/nix-community/nixos-anywhere

resource "null_resource" "nixos_anywhere" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  # Reinstall triggern wenn die VM neu erstellt wurde
  triggers = {
    vm_id = proxmox_virtual_environment_vm.vm.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      nixos-anywhere \
        --build-on-remote \
        --flake "${var.nixos_flake_ref}" \
        -i "${var.ssh_private_key_path}" \
        root@${local.vm_ip}
    EOT
  }
}
