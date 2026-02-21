# Deklaratives Disk-Layout via disko
# Ersetzt: packer/nixos-base/scripts/install-nixos.sh + nixos/modules/hardware-vm.nix fileSystems
#
# Referenz: https://github.com/nix-community/disko
#
# Disk-Device: /dev/vda (virtio-blk in Proxmox, Terraform disk interface = "virtio0")
# Layout: GPT | 512M EFI System Partition | Rest ext4 root

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

            ESP = {
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
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
