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
    "virtio_blk" # fuer /dev/vda (virtio0 disk interface)
    "sd_mod"
    "sr_mod"
  ];

  boot.initrd.kernelModules  = [ ];
  boot.kernelModules         = [ ];
  boot.extraModulePackages   = [ ];
}
