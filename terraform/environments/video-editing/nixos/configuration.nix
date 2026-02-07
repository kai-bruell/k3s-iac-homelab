{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # Grafik: Virtuelles VGA (virtio) mit 1080p
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics.enable = true;

  # 1080p Aufloesung erzwingen fuer virtuelles Display
  services.xserver.xrandrHeads = [
    {
      output = "Virtual-1";
      monitorConfig = ''
        Modeline "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
        Option "PreferredMode" "1920x1080_60.00"
      '';
    }
  ];

  # GNOME Desktop (X11, kein Wayland - Sunshine braucht X11 fuer Cursor-Capture)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = false;
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
