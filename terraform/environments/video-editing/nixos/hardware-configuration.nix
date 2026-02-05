{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];

  # GRUB Bootloader (kompatibel mit proxmox VMA Format)
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # QEMU Guest Agent
  services.qemuGuest.enable = true;
}
