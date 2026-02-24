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

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    # Sway explizit auf NVIDIA-GBM zeigen (fallback wenn kein KMS)
    WLR_RENDERER = "gles2";
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
  ];

  # SSH Public Keys fuer Root-Login
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];
}
