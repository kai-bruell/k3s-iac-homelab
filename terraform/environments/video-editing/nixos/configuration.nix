{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # NVIDIA GTX 760 (Kepler) mit Dummy HDMI Plug
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    modesetting.enable = true;
  };

  # 1080p erzwingen (Dummy HDMI Plug)
  services.xserver.screenSection = ''
    Option "MetaModes" "1920x1080 +0+0"
  '';

  # Wayland deaktivieren (470er Treiber unterstuetzt kein Wayland)
  services.xserver.displayManager.gdm.wayland = false;

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
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoUXRrEIdgqYhCtpO5CxxBpyPtLtJ7a89zB+o6j/koD user@fedora"
    ];
    linger = true;
  };

  # Pakete
  environment.systemPackages = with pkgs; [
    kdenlive
    git
    distrobox
    pciutils
  ];

  # Kdenlive Settings
  systemd.services.kdenlive-setup = {
    description = "Clone Kdenlive portable dots";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "user";
      ExecStart = "${pkgs.bash}/bin/bash -c '[ -d /home/user/Kdenlive ] || ${pkgs.git}/bin/git clone https://github.com/kai-bruell/kdenlive-portable-dots.git /home/user/Kdenlive'";
      RemainAfterExit = true;
    };
  };

  # Performance
  powerManagement.cpuFreqGovernor = "performance";

  # SSH
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
