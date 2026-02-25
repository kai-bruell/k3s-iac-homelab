# Host-spezifische Konfiguration: videoediting

{ config, pkgs, lib, ... }:

{
  networking = {
    hostName = "videoediting";

    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks."10-eth" = {
      matchConfig.Name = "en*";
      networkConfig = {
        Address = "192.168.178.181/24";
        Gateway = "192.168.178.199";
        DNS     = "192.168.178.199";
      };
    };
  };

  # Kernel 6.6 LTS – Pflicht fuer NVIDIA 470 Legacy-Treiber (bricht ab Kernel 6.11)
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # NVIDIA GTX 760 (Kepler GK104) via PCI-Passthrough
  # Kernel-Param: efifb/vesafb deaktivieren damit NVIDIA den Framebuffer übernehmen kann
  boot.kernelParams = [ "video=efifb:off" "video=vesafb:off" ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
  nixpkgs.config.nvidia.acceptLicense = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    # modesetting (nvidia-drm KMS) schlaegt auf Kepler/470 Legacy + Passthrough fehl:
    # "Failed to allocate NvKmsKapiDevice" -> deaktiviert
    modesetting.enable = false;
    open = false;
    powerManagement.enable = false;
  };

  # Sway (Wayland) – experimentell auf NVIDIA 470 Legacy
  # modesetting ist deaktiviert -> WLR_NO_HARDWARE_CURSORS + --unsupported-gpu als Workaround
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraOptions = [ "--unsupported-gpu" ];
    extraConfig = ''
      output Virtual-1 mode 1920x1080@60Hz scale 1
    '';
  };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    # Sway explizit auf NVIDIA-GBM zeigen (fallback wenn kein KMS)
    WLR_RENDERER = "gles2";
  };

  # Podman – Container-Backend fuer Distrobox
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
  };

  environment.systemPackages = with pkgs; [
    # Sway-Basis
    swaylock
    swayidle
    swaybg
    # Terminal
    foot
    # Status-Bar
    waybar
    # App-Launcher
    dmenu
    rofi
    # Tiling-Helper (via chezmoi sway config referenziert)
    autotiling
    # Tools
    neovim
    tmux
    git
    curl
    # Dotfile-Management
    chezmoi
    # Distrobox + Container-Runtime
    distrobox
  ];

  # Zsh als Default-Shell fuer Root
  programs.zsh.enable = true;
  users.users.root.shell = pkgs.zsh;

  # Chezmoi: Dotfiles beim ersten Boot automatisch anwenden
  # Laeuft einmalig (ConditionPathExists verhindert Wiederholung)
  systemd.services.chezmoi-apply = {
    description = "Apply chezmoi dotfiles on first boot";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/root/.local/share/chezmoi/.git";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    path   = with pkgs; [ chezmoi git curl bash zsh ];
    script = ''
      chezmoi init --apply \
        https://github.com/kai-bruell/Chezmoi-Dotfiles
    '';
  };

  # Auto-Login auf TTY1 + Sway automatisch starten
  # loginShellInit fuer zsh (Root-Shell) – bash-Variante greift nicht mehr
  services.getty.autologinUser = "root";
  programs.zsh.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      export WLR_RENDERER_ALLOW_SOFTWARE=1
      exec dbus-run-session sway
    fi
  '';

  # uinput – virtuelle Eingabegeraete fuer Sunshine (Maus/Tastatur-Forwarding)
  hardware.uinput.enable = true;

  # Sunshine – Desktop-Streaming Server (Moonlight-kompatibel)
  # capSysAdmin: benoetigt fuer KMS/DRM-Capture (Wayland-Frame-Grab)
  # openFirewall: TCP 47984-47990/48010, UDP 47998-48000/48002/48010
  services.sunshine = {
    enable      = true;
    autoStart   = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # Sunshine laeuft als systemd-User-Service – braucht WAYLAND_DISPLAY
  # Sway legt den Socket als root unter wayland-1 ab
  systemd.user.services.sunshine.environment = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_RUNTIME_DIR = "/run/user/0";
  };

  # Avahi/mDNS – automatische Erkennung durch Moonlight im Netzwerk
  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    publish = {
      enable       = true;
      userServices = true;
    };
  };

  # Distrobox: alle Boxen beim ersten Boot installieren
  # Laeuft einmalig (ConditionPathExists verhindert Wiederholung)
  systemd.services.distrobox-install = {
    description = "Install distroboxes on first boot";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" "podman.socket" ];
    wants       = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/root/DistroBoxes/.git";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    path   = with pkgs; [ distrobox git bash podman gnused ];
    script = ''
      git clone https://github.com/kai-bruell/DistroBoxes /root/DistroBoxes
      bash /root/DistroBoxes/install.sh
    '';
  };

  # SSH Public Keys fuer Root-Login
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];
}
