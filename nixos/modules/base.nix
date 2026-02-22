{ config, pkgs, lib, ... }:

{
  # Boot (BIOS/GRUB)
  # device wird von disko automatisch gesetzt (EF02-Partition in disko.nix)
  boot.loader.grub.enable = true;

  # Locale und Zeitzone
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de";

  # SSH (Root nur mit Key)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Nix Flakes aktivieren
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatische Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Basis-Pakete
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
  ];

  # Firewall Basis
  networking.firewall.enable = true;

  # NixOS State Version
  system.stateVersion = "24.11";
}
