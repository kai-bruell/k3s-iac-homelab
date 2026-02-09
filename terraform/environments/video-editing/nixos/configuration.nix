{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./smb-mount.nix
    ];

  # Bootloader Einstellungen für UEFI (Proxmox OVMF)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- NVIDIA & KERNEL BLOCK ---

  # Unfree Software für NVIDIA erlauben
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  # Kernel 6.6 LTS erzwingen (NVIDIA 470 braucht diesen Kernel)
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # NVIDIA Treiber für GTX 760 (Kepler)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidia_x11_legacy470;
    modesetting.enable = true;
    open = false;
    powerManagement.enable = false; # Sicherer für Passthrough
  };

  # Proxmox Guest Agent für ordentliches Shutdown/IP-Anzeige
  services.qemuGuest.enable = true;

  # --- DESKTOP & USER BLOCK ---

  # X11 und XFCE Desktop
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kai";
  services.xserver.desktopManager.xfce.enable = true;

  # Deutsches Tastaturlayout
  services.xserver.xkb.layout = "de";
  console.keyMap = "de";

  # User "Kai Brüll"
  users.users.kai = {
    isNormalUser = true;
    description = "Kai Brüll";
    extraGroups = [ "networkmanager" "wheel" "video" "input" ];
    packages = with pkgs; [
      firefox
      # Weitere Pakete hier hinzufügen
    ];
  };

  # Distrobox + Podman für AppImages und Linux-native Apps
  virtualisation.podman.enable = true;
  environment.systemPackages = with pkgs; [
    distrobox
  ];

  # Sunshine Streaming Server
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # uinput für Sunshine virtuelle Maus/Tastatur
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"
  '';

  # --- ORIGINALER REST ---

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "25.11";

}


