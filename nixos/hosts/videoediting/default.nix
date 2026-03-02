# Host configuration: videoediting
#
# VM with virtio-gpu display, running Sway/Wayland.
# Sunshine game streaming with software (libx264) encoding.

{ pkgs, ... }:

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

  # --- Wayland / Sway -------------------------------------------------------

  hardware.graphics.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER = "pixman";  # force software renderer – fixes damage-tracking flicker on virtio-gpu
    # Force seatd as libseat backend so serial-getty (ttyS0) doesn't grab
    # DRM master via logind and break the tty1 Sway session.
    LIBSEAT_BACKEND = "seatd";
  };

  # Configure the single virtual display.
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
      # kms: reads raw KMS/DRM framebuffer. Previously caused flickering, but
      # that was a compositor damage-tracking bug (now fixed via WLR_RENDERER=pixman).
      # wlr capture requires EGL which is unavailable with the pixman renderer.
      capture   = "kms";
      # zerolatency: disables B-frames and lookahead → minimal encoding latency.
      # qp=23: quality floor to prevent macroblocking spikes on motion transitions.
      sw_preset = "fast";
      sw_tune   = "zerolatency";
      qp        = "18";
    };
  };

  # Sunshine runs as a systemd user service.
  systemd.user.services.sunshine.environment = {
    XDG_RUNTIME_DIR  = "/run/user/1000";
    WAYLAND_DISPLAY  = "wayland-1";  # required for wlr-screencopy capture
  };

  # Avahi/mDNS: Moonlight clients auto-discover this host on the local network.
  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    publish  = {
      enable       = true;
      userServices = true;   # Sunshine service discovery
      addresses    = true;   # NDI source discovery
    };
  };

  networking.firewall = {
    enable = true;
    # NDI Discovery (mDNS)
    allowedUDPPorts = [ 5353 ];
    # NDI Video Streams
    allowedTCPPortRanges = [
      { from = 5959; to = 5970; }
    ];
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
      TimeoutStartSec = "10min";
    };
    path   = with pkgs; [ chezmoi git curl bash zsh ];
    script = ''
      # Wait until GitHub is actually reachable (DNS + internet, not just link-up).
      until curl -sf --head --max-time 5 https://github.com > /dev/null 2>&1; do
        echo "Waiting for internet connectivity..."
        sleep 10
      done

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

  # --- Flatpak ------------------------------------------------------------------

  services.flatpak = {
    enable  = true;
    remotes = [
      { name = "flathub"; location = "https://dl.flathub.org/repo/flathub.flatpakrepo"; }
    ];
    packages = [
      { appId = "com.obsproject.Studio";            origin = "flathub"; }
      { appId = "com.obsproject.Studio.Plugin.NDI"; origin = "flathub"; }
      { appId = "org.videolan.VLC";                 origin = "flathub"; }
    ];
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
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
      TimeoutStartSec = "30min";
    };
    path   = with pkgs; [ distrobox git bash podman gnused curl ];
    script = ''
      # Wait until GitHub is actually reachable (DNS + internet, not just link-up).
      until curl -sf --head --max-time 5 https://github.com > /dev/null 2>&1; do
        echo "Waiting for internet connectivity..."
        sleep 10
      done

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
