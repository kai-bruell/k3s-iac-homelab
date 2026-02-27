# Host configuration: videoediting
#
# VM with PCI-passthrough NVIDIA GTX 760 (Kepler, 470 legacy driver).
# Display: virtio-gpu (card0) running Sway/Wayland.
# NVIDIA (card1): used exclusively for NVENC encoding via Sunshine – no display output.

{ config, pkgs, lib, ... }:

{
  # --- Networking -----------------------------------------------------------

  networking = {
    hostName  = "videoediting";
    useNetworkd = true;
    useDHCP   = false;
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

  # --- Kernel ---------------------------------------------------------------

  # Linux 6.6 LTS required: NVIDIA 470 legacy driver breaks on kernel >= 6.11.
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # nvidia_uvm: CUDA UVM module required for NVENC hardware encoding (Sunshine).
  boot.kernelModules = [ "nvidia_uvm" ];

  # Prevent the kernel from claiming the NVIDIA GPU's framebuffer before the
  # 470 driver initialises it.
  boot.kernelParams = [ "video=efifb:off" "video=vesafb:off" ];

  # --- NVIDIA (PCI passthrough – encoding only) -----------------------------

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
  nixpkgs.config.nvidia.acceptLicense = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    # KMS modesetting fails on Kepler + passthrough ("Failed to allocate NvKmsKapiDevice").
    # Not needed here – NVIDIA is not the display adapter.
    modesetting.enable    = false;
    open                  = false;
    powerManagement.enable = false;
  };

  # --- Wayland / Sway -------------------------------------------------------

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # Sway detects the NVIDIA GPU but modesetting is off; suppress the resulting error.
    extraOptions = [ "--unsupported-gpu" ];
  };

  # Restrict wlroots to virtio-gpu (card0). NVIDIA (card1) has no KMS/modesetting
  # and cannot be opened as a DRM device.
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_DRM_DEVICES         = "/dev/dri/card0";
    # Force seatd as libseat backend so serial-getty (ttyS0) doesn't grab
    # DRM master via logind and break the tty1 Sway session.
    LIBSEAT_BACKEND = "seatd";
  };

  # Set FHD resolution for the single virtual display.
  environment.etc."sway/config.d/99-output.conf".text = ''
    output Virtual-1 resolution 1920x1080 position 0,0 scale 1
  '';

  # seatd manages DRM master directly, bypassing logind session conflicts.
  services.seatd.enable = true;

  # Auto-login on TTY1 and start Sway immediately.
  services.getty.autologinUser = "user";
  programs.zsh.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      exec dbus-run-session sway > /tmp/sway.log 2>&1
    fi
  '';

  # --- Sunshine (game streaming) --------------------------------------------

  # uinput: virtual input devices for Sunshine keyboard/mouse forwarding.
  hardware.uinput.enable = true;

  services.sunshine = {
    enable      = true;
    autoStart   = true;
    capSysAdmin = true;
    openFirewall = true;   # TCP 47984-47990/48010, UDP 47998-48000/48002/48010
    settings = {
      # KMS capture reads the virtio-gpu framebuffer (card0) directly via DRM.
      # wlr-screencopy would be preferable (vsync-synchronized) but requires EGL
      # DMA-BUF import on the encoder GPU. With NVIDIA passthrough as encoder and
      # virtio-gpu as display, Sunshine initialises EGL on NVIDIA which cannot import
      # virtio-gpu DMA-BUFs → wlr capture fails. KMS works without EGL.
      capture = "kms";
      # NVENC and VAAPI both fail in this setup; Sunshine falls back to libx264.
      # Default preset is ultrafast → heavy macroblocking on motion.
      # fast+zerolatency gives significantly better quality at acceptable CPU cost.
      sw_preset = "fast";
      sw_tune   = "zerolatency";
    };
  };

  # Sunshine runs as a systemd user service.
  systemd.user.services.sunshine.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000";
  };

  # Avahi/mDNS: Moonlight clients auto-discover this host on the local network.
  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    publish  = {
      enable       = true;
      userServices = true;
    };
  };

  # --- Audio ----------------------------------------------------------------

  security.rtkit.enable = true;
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    pulse.enable       = true;   # PulseAudio compat for pavucontrol + Sunshine
    wireplumber.enable = true;
  };

  # --- User, shell & dotfiles -----------------------------------------------

  users.users.user = {
    isNormalUser = true;
    shell        = pkgs.zsh;
    linger       = true;   # start systemd user instance at boot (needed for rootless Podman)
    extraGroups  = [ "wheel" "video" "input" "audio" "render" "seat" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];

  security.sudo.wheelNeedsPassword = false;
  programs.zsh.enable = true;

  # Stub .zshrc so zsh-newuser-install doesn't block auto-login/Sway start on TTY1.
  systemd.tmpfiles.rules = [
    "f /home/user/.zshrc 0644 user users - "
  ];

  # Apply chezmoi dotfiles on first boot (skipped if repo already present).
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
      # NixOS has no /bin/bash; tell chezmoi to use bash from PATH for run_ scripts.
      mkdir -p /home/user/.config/chezmoi
      cat > /home/user/.config/chezmoi/chezmoi.toml <<EOF
[interpreters.sh]
  command = "bash"
  args = []
EOF
      chezmoi init --apply https://github.com/kai-bruell/Chezmoi-Dotfiles
    '';
  };

  # --- Containers (Distrobox) -----------------------------------------------

  virtualisation.podman = {
    enable       = true;
    dockerCompat = false;
  };

  # Clone and install all Distroboxes on first boot.
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
      # newuidmap/newgidmap for rootless Podman are setuid wrappers in /run/wrappers/bin.
      export PATH="/run/wrappers/bin:$PATH"
      git clone https://github.com/kai-bruell/DistroBoxes /home/user/DistroBoxes
      bash /home/user/DistroBoxes/install.sh
    '';
  };

  # --- Packages & Fonts -----------------------------------------------------

  environment.systemPackages = with pkgs; [
    # Sway ecosystem
    swaylock swayidle swaybg autotiling waybar foot dmenu rofi wlr-randr
    # Tools
    neovim tmux git curl jq chezmoi distrobox
    # Audio
    pavucontrol
  ];

  fonts.packages = with pkgs; [
    font-awesome  # Waybar icons
    noto-fonts
  ];
}
