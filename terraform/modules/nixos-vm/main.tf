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

# --- cloud-init user-data ---
#
# Vorbedingung: Snippets auf Proxmox Storage aktivieren (einmalig):
#   pvesm set local --content snippets,iso,vztmpl,backup

resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.node_name

  source_raw {
    file_name = "nixos-bootstrap-${var.vm_name}.yaml"
    # WICHTIG: user_data_file_id ueberschreibt Proxmox's eigene User-Data-Generierung.
    # SSH-Keys und qemu-guest-agent muessen daher beide hier definiert werden.
    data = <<-EOF
      #cloud-config
      users:
        - name: root
          ssh_authorized_keys: ${jsonencode(var.ssh_public_keys)}
      packages:
        - qemu-guest-agent
        - zsh
      runcmd:
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
      EOF
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
# NixOS ueberschreibt das geklonte Debian-Disk (/dev/sda) komplett via disko.
#
# WICHTIG – GPU-Passthrough (machine_type + hostpci):
#   machine_type = "q35" ist Pflicht fuer PCIe-Passthrough (pcie=true).
#   Das Bootstrap-Template muss nativ als q35 erstellt sein (sata1 fuer cloud-init,
#   qemu-guest-agent vorinstalliert) – siehe proxmox-template/README.md.

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  bios    = var.bios
  machine = var.machine_type

  clone {
    vm_id = var.bootstrap_template_id
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

  # Kein disk-Block: Disk-Groesse wird einmalig am Template (VM 9000) gesetzt:
  #   qm resize 9000 scsi0 20G
  # Ein Terraform disk-Block wuerde scsi0 als nachgelagerten Update-Step resizen –
  # das passiert NACH nixos-anywhere und korrumpiert das laufende NixOS-System.

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Serieller Port fuer Konsolen-Logging (qm terminal <vmid> auf Proxmox Host)
  serial_device {}

  # VGA auf virtio setzen: vollstaendiges DRM/KMS inkl. Cursor-Support
  # bochs/std fehlt drmModeSetCursor -> wlroots Legacy-Commit schlaegt fehl -> Blackscreen
  # noVNC/VNC-Konsole bleibt aktiv (QEMU captured virtio-gpu framebuffer fuer VNC)
  vga {
    type = "virtio"
  }

  # EFI-Disk: nur bei bios=ovmf benoetigt
  dynamic "efi_disk" {
    for_each = var.efi_disk_datastore != null ? [var.efi_disk_datastore] : []
    content {
      datastore_id = efi_disk.value
      file_format  = "raw"
      type         = "4m"
    }
  }

  # GPU-Passthrough: PCIe-Geraet direkt an VM durchreichen
  #
  # Funktionierende Konfiguration (GTX 760 / Kepler GK104, SeaBIOS, q35):
  #   pcie    = true  -> korrekte PCIe-Praesentation (Pflicht fuer machine = "q35")
  #   rombar  = true  -> vBIOS lesbar (sonst: Failed to allocate NvKmsKapiDevice)
  #   xvga    = true  -> GPU als primaeres VGA: SeaBIOS fuehrt vBIOS-Option-ROM aus
  #                      -> GPU wird initialisiert -> UUID lesbar -> nvidia-smi funktioniert
  #                      (ohne xvga=true: UUID = ??, nvidia-smi: No devices were found)
  dynamic "hostpci" {
    for_each = var.hostpci_id != null ? [var.hostpci_id] : []
    content {
      device  = "hostpci0"
      id      = hostpci.value
      pcie    = true   # PCIe-Modus (erfordert machine = "q35")
      rombar  = true   # vBIOS muss lesbar sein (sonst: Failed to allocate NvKmsKapiDevice)
      xvga    = true   # GPU als primaeres VGA -> SeaBIOS fuehrt vBIOS-Option-ROM aus -> GPU wird initialisiert
    }
  }

  # QEMU Guest Agent: wird per cloud-init user-data installiert (s.o.)
  agent {
    enabled = true
  }

  # Cloud-init: user-data enthaelt SSH-Keys + qemu-guest-agent Installation
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id

    ip_config {
      ipv4 { address = "dhcp" }
    }
  }

}

# --- Erste nicht-loopback IPv4 der VM ermitteln ---
# Wird vom QEMU Guest Agent gemeldet sobald cloud-init abgeschlossen hat
locals {
  vm_ip = [
    for ip in flatten(proxmox_virtual_environment_vm.vm.ipv4_addresses) :
    ip if !startswith(ip, "127.")
  ][0]
}

# --- NixOS via nixos-anywhere CLI installieren ---
#
# Was nixos-anywhere macht:
#   1. Laedt kexec-Tarball auf die Bootstrap-VM
#   2. Fuehrt kexec aus: VM bootet in NixOS-Installer (kein Reboot der Hardware)
#   3. Fuehrt disko aus: partitioniert /dev/sda deklarativ (aus Flake)
#   4. Installiert NixOS via nixos-install (Build auf der VM, kein lokales nix build)
#   5. Reboot: VM startet mit finalem NixOS und statischer IP aus dem Flake
#
# Voraussetzung lokal: nixos-anywhere Binary (via devbox bereitgestellt)
# Referenz: https://github.com/nix-community/nixos-anywhere

resource "null_resource" "nixos_anywhere" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.vm.id
  }

  provisioner "local-exec" {
    # SHELL auf bash setzen: nixos-anywhere nutzt $SHELL fuer Remote-Befehle,
    # der kexec-NixOS-Installer hat kein zsh
    environment = {
      SHELL = "/bin/bash"
    }
    command = <<-EOT
      nixos-anywhere \
        --flake "${var.nixos_flake_ref}" \
        -i "${pathexpand(var.ssh_private_key_path)}" \
        root@${local.vm_ip}
    EOT
  }
}
