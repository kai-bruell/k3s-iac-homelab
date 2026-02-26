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
  };

  # Sway output config: FHD via swaymsg setzen
  # - wlr-randr --mode schlaegt mit pixman-Renderer fehl (kein DRM-Modeswitch)
  # - nativer Sway output-Block klappt mit pixman (frueherer Blackscreen war gles2-spezifisch)
  environment.etc."sway/config.d/99-output.conf".text = ''
    output Virtual-1 resolution 1920x1080 position 0,0 scale 1
  '';

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    # pixman: nativer CPU-Renderer fuer headless/virtuelles Display (kein EGL/OpenGL noetig)
    # gles2 lief ueber llvmpipe (Software-Mesa) -> fehlende Frame-Sync -> Hover-Flickering
    WLR_RENDERER = "pixman";
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
    # Audio
    pavucontrol
    # Display-Management
    wlr-randr
  ];

  # User 'user' – normaler Account statt root
  users.users.user = {
    isNormalUser = true;
    shell        = pkgs.zsh;
    # linger: user-Systemd-Instanz startet beim Boot (braucht /run/user/1000 fuer Podman rootless)
    linger       = true;
    extraGroups  = [ "wheel" "video" "input" "audio" "render" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
    ];
  };

  # Sudo ohne Passwort fuer wheel (Homelab)
  security.sudo.wheelNeedsPassword = false;

  # Zsh als Default-Shell
  programs.zsh.enable = true;

  # Chezmoi: Dotfiles beim ersten Boot automatisch anwenden
  # Laeuft einmalig (ConditionPathExists verhindert Wiederholung)
  systemd.services.chezmoi-apply = {
    description = "Apply chezmoi dotfiles on first boot";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/home/user/.local/share/chezmoi/.git";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      User            = "user";
      Environment     = [ "HOME=/home/user" ];
    };
    path   = with pkgs; [ chezmoi git curl bash zsh ];
    script = ''
      chezmoi init --apply \
        https://github.com/kai-bruell/Chezmoi-Dotfiles
    '';
  };

  # Auto-Login auf TTY1 + Sway automatisch starten
  services.getty.autologinUser = "user";
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
  # Sway legt den Socket unter /run/user/1000/wayland-1 ab (user UID 1000)
  systemd.user.services.sunshine.environment = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_RUNTIME_DIR = "/run/user/1000";
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
  # Laeuft als 'user' mit rootless Podman (linger = true sichert /run/user/1000)
  systemd.services.distrobox-install = {
    description = "Install distroboxes on first boot";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/home/user/DistroBoxes/.git";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      User            = "user";
      Environment     = [
        "HOME=/home/user"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
    };
    path   = with pkgs; [ distrobox git bash podman gnused ];
    script = ''
      # newuidmap/newgidmap fuer rootless Podman liegen als setuid-Wrapper in /run/wrappers/bin
      # (nicht im Nix-Store, deshalb explizit vorne einhängen)
      export PATH="/run/wrappers/bin:$PATH"
      git clone https://github.com/kai-bruell/DistroBoxes /home/user/DistroBoxes
      bash /home/user/DistroBoxes/install.sh
    '';
  };

  # Audio: PipeWire mit PulseAudio-Kompatibilitaet (benoetigt fuer pavucontrol + Sunshine)
  security.rtkit.enable = true;
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    pulse.enable       = true;
    wireplumber.enable = true;
  };


  # Fonts fuer Waybar (font-awesome Icons + Noto Sans Mono Text)
  fonts.packages = with pkgs; [
    font-awesome
    noto-fonts
  ];

  # SSH Public Keys: root-Zugang als Fallback behalten (base.nix: PermitRootLogin = prohibit-password)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];
}
