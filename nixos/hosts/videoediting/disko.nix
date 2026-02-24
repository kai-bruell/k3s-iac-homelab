# Deklaratives Disk-Layout via disko – BIOS/GRUB
# Layout: GPT | 1M BIOS-Boot-Partition (fuer GRUB) | Rest ext4 root
#
# Referenz: https://github.com/nix-community/disko

{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";
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
