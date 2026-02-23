# Hardware-Konfiguration fuer QEMU/KVM VMs auf Proxmox
#
# Enthaelt: Kernel-Module fuer virtio, QEMU Guest Profile
# Nicht enthalten: fileSystems, swapDevices -> wird von disko generiert
#                  (siehe hosts/<hostname>/disko.nix)

{ modulesPath, ... }:

{
  imports = [
    # Bringt QEMU Guest Agent + virtio Basis-Unterstuetzung
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Kernel-Module fuer Proxmox Q35 + virtio-blk/scsi
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "sr_mod"
  ];

  boot.initrd.kernelModules  = [ ];
  boot.kernelModules         = [ ];
  boot.extraModulePackages   = [ ];

  # Serielle Konsole: Output auf ttyS0 (Proxmox serial_device) + normales tty0
  # Verbinden: qm terminal <vmid> (auf Proxmox Host)
  # boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  # Partition und Filesystem beim Boot automatisch auf Disk-Groesse erweitern.
  # Ermoeglicht: VM stoppen -> qm resize <id> scsi0 <size>G -> starten -> fertig.
  boot.growPartition = true;
}
