terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
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
#      qm importdisk 9000 debian-12-genericcloud-amd64.qcow2 local-zfs
#      qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
#      qm set 9000 --boot c --bootdisk scsi0 --ide2 local-zfs:cloudinit --agent 1
#      qm template 9000
#
# nixos-anywhere verbindet sich per SSH auf dieses Bootstrap-Image,
# bootet via kexec in den NixOS-Installer und installiert das finale System aus dem Flake.
# Das Bootstrap-Image wird dabei komplett ueberschrieben.

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  bios    = "ovmf"
  machine = "q35"

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

  # OVMF NVRAM (UEFI-Variablen, separates Proxmox-Objekt – kein Block-Device im Gast)
  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # QEMU Guest Agent: noetig damit Proxmox die DHCP-IP melden kann
  agent {
    enabled = true
  }

  # Cloud-init: SSH-Key injecten, DHCP fuer nixos-anywhere Deploy
  # Nach nixos-anywhere bekommt die VM die statische IP aus dem Nix-Flake
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
# bpg/proxmox meldet alle IPs via QEMU Guest Agent sobald die VM gebootet hat
locals {
  vm_ip = [
    for ip in flatten(proxmox_virtual_environment_vm.vm.ipv4_addresses) :
    ip if !startswith(ip, "127.")
  ][0]
}

# --- NixOS via nixos-anywhere installieren ---
#
# Was nixos-anywhere macht:
#   1. Laedt kexec-Tarball auf die Bootstrap-VM (Debian)
#   2. Fuehrt kexec aus: VM bootet in NixOS-Installer (kein Reboot der Hardware)
#   3. Fuehrt disko aus: partitioniert /dev/vda deklarativ (Konfiguration aus Flake)
#   4. Installiert NixOS aus dem Flake via nixos-install
#   5. Reboot: VM startet mit finalem NixOS und statischer IP aus dem Flake
#
# Voraussetzung lokal: nix muss installiert sein (nixos-anywhere wird via `nix run` aufgerufen)
# Referenz: https://github.com/nix-community/nixos-anywhere

module "nixos_anywhere" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  # Flake-Attribut des Zielsystems (muss in nixos/flake.nix definiert sein)
  nixos_system_attr = var.nixos_system_attr

  # Bootstrap-VM IP (DHCP, temporaer – nach Install hat die VM die statische IP aus dem Flake)
  target_host = local.vm_ip

  # Eindeutige ID: triggert Reinstall wenn sich die VM-ID aendert (d.h. VM wurde neu erstellt)
  instance_id = tostring(proxmox_virtual_environment_vm.vm.id)

  # Privater SSH-Key (Inhalt, nicht Pfad) fuer die Verbindung zur Bootstrap-VM
  ssh_private_key = file(var.ssh_private_key_path)
}
