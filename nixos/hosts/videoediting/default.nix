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

  # SSH Public Keys fuer Root-Login
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];
}
