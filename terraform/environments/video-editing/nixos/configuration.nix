{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Kernel LTS fuer Legacy-Treiber Kompatibilitaet
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # NVIDIA Legacy 470 (GTX 760 / Kepler)
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true; # NVENC/VAAPI fuer Video-Encoding
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
  };

  # GNOME Desktop
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "user";
  };

  # Sunshine (Remote Desktop Streaming)
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # User
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoUXRrEIdgqYhCtpO5CxxBpyPtLtJ7a89zB+o6j/koD user@fedora"
    ];
  };

  # Pakete
  environment.systemPackages = with pkgs; [
    kdenlive
    git
    distrobox
    pciutils
  ];

  # Kdenlive Settings (klont kdenlive-portable-dots beim ersten Boot)
  system.activationScripts.kdenlive-setup = ''
    KDENLIVE_DIR="/home/user/Kdenlive"
    if [ ! -d "$KDENLIVE_DIR" ]; then
      ${pkgs.git}/bin/git clone https://github.com/kai-bruell/kdenlive-portable-dots.git "$KDENLIVE_DIR"
      chown -R user:users "$KDENLIVE_DIR"
    fi
  '';

  # Performance
  powerManagement.cpuFreqGovernor = "performance";

  # SSH fuer Remote-Management
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
