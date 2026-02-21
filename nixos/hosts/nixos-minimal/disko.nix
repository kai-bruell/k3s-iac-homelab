# Deklaratives Disk-Layout via disko
# Ersetzt: packer/nixos-base/scripts/install-nixos.sh + nixos/modules/hardware-vm.nix fileSystems
#
# Referenz: https://github.com/nix-community/disko
#
# Disk-Device: /dev/vda (virtio-blk in Proxmox, Terraform disk interface = "virtio0")
# Layout: GPT | 1M BIOS-Boot-Partition (fuer GRUB) | Rest ext4 root

{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {

            # GRUB braucht bei GPT eine kleine BIOS-Boot-Partition (kein Filesystem)
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot partition
              priority = 1;
            };

            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };

          };
        };
      };
    };
  };
}
