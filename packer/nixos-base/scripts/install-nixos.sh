#!/usr/bin/env bash
set -euo pipefail

echo "=== NixOS Installation ==="

# --- Partitionierung ---
# GPT-Layout: 512MB EFI System Partition + Rest als root
# Labels (BOOT, nixos) werden spaeter in hardware-vm.nix referenziert
echo "--- Partitionierung ---"
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary 512MiB 100%

echo "--- Dateisysteme formatieren ---"
mkfs.fat -F 32 -n BOOT /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

# udev muss die neuen Labels erkennen bevor wir mounten
echo "--- Warte auf udev Labels ---"
udevadm settle --timeout=10

echo "--- Mounten ---"
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

# nixos-generate-config erzeugt hardware-configuration.nix mit den erkannten
# Kernel-Modulen und Dateisystemen. Wir ueberschreiben configuration.nix danach,
# aber hardware-configuration.nix bleibt (wird vom Template importiert).
echo "--- Hardware-Konfiguration generieren ---"
nixos-generate-config --root /mnt

# Minimale Konfiguration: Nur was noetig ist um die VM zu booten und per SSH
# erreichbar zu machen. Alles Weitere kommt spaeter via nixos-rebuild mit dem
# Flake aus dem Git-Repo (deployed durch Terraform).
echo "--- Minimale NixOS-Konfiguration schreiben ---"
cat > /mnt/etc/nixos/configuration.nix << NIXCONFIG
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # UEFI Boot mit systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # DHCP: Template bootet mit DHCP, statische IP kommt erst durch nixos-rebuild
  networking.hostName = "nixos-template";

  # SSH: Root-Login nur mit Key (Passwort-Auth komplett aus)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # QEMU Guest Agent: Proxmox braucht diesen um die VM-IP abzufragen
  services.qemuGuest.enable = true;

  # Root SSH Keys (damit Terraform sich nach dem Clone verbinden kann)
  users.users.root.openssh.authorizedKeys.keys = [
    "${SSH_KEYS}"
  ];

  system.stateVersion = "24.11";
}
NIXCONFIG

echo "--- NixOS installieren ---"
# --no-root-passwd: Kein Root-Passwort, Login nur per SSH Key
nixos-install --no-root-passwd

echo "=== NixOS Installation abgeschlossen ==="
