{ config, pkgs, lib, ... }:

let
  # Virtuelle EDID-Datei (1920x1080@60Hz) - simuliert einen Monitor
  # Standard EDID-Block fuer Full HD Display
  virtualEdid = pkgs.runCommand "virtual-edid" {} ''
    mkdir -p $out
    # EDID 1.3 Block fuer 1920x1080@60Hz Virtual Display
    printf '\x00\xff\xff\xff\xff\xff\xff\x00' > $out/edid.bin      # Header
    printf '\x1e\x6d\x01\x00\x01\x01\x01\x01' >> $out/edid.bin     # Manufacturer (LG)
    printf '\x01\x1b\x01\x03\x80\x35\x1e\x78' >> $out/edid.bin     # EDID Version 1.3
    printf '\x0a\xee\x91\xa3\x54\x4c\x99\x26' >> $out/edid.bin     # Display params
    printf '\x0f\x50\x54\x21\x08\x00\x81\x80' >> $out/edid.bin     # Established timings
    printf '\xa9\xc0\x71\x4f\xb3\x00\x01\x01' >> $out/edid.bin     # Standard timings
    printf '\x01\x01\x01\x01\x01\x01\x02\x3a' >> $out/edid.bin     # Detailed timing header
    printf '\x80\x18\x71\x38\x2d\x40\x58\x2c' >> $out/edid.bin     # 1920x1080 timing
    printf '\x45\x00\x0f\x28\x21\x00\x00\x1e' >> $out/edid.bin     # Timing descriptor
    printf '\x00\x00\x00\xfd\x00\x38\x4b\x1e' >> $out/edid.bin     # Monitor range
    printf '\x51\x11\x00\x0a\x20\x20\x20\x20' >> $out/edid.bin     # Range limits
    printf '\x20\x20\x00\x00\x00\xfc\x00\x56' >> $out/edid.bin     # Monitor name header
    printf '\x69\x72\x74\x75\x61\x6c\x20\x48' >> $out/edid.bin     # "Virtual H"
    printf '\x44\x0a\x20\x20\x00\x00\x00\xff' >> $out/edid.bin     # "D\n"
    printf '\x00\x30\x30\x30\x30\x30\x30\x30' >> $out/edid.bin     # Serial
    printf '\x30\x30\x30\x30\x31\x0a\x00\xc0' >> $out/edid.bin     # Checksum
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  # Kernel LTS fuer Legacy-Treiber Kompatibilitaet
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # EDID Firmware fuer Headless GPU - laedt beim Kernel-Start
  hardware.firmware = [
    (pkgs.runCommand "edid-firmware" {} ''
      mkdir -p $out/lib/firmware/edid
      # 1920x1080@60Hz EDID
      printf '\x00\xff\xff\xff\xff\xff\xff\x00' > $out/lib/firmware/edid/virtual.bin
      printf '\x1e\x6d\x01\x00\x01\x01\x01\x01' >> $out/lib/firmware/edid/virtual.bin
      printf '\x01\x1b\x01\x03\x80\x35\x1e\x78' >> $out/lib/firmware/edid/virtual.bin
      printf '\x0a\xee\x91\xa3\x54\x4c\x99\x26' >> $out/lib/firmware/edid/virtual.bin
      printf '\x0f\x50\x54\x21\x08\x00\x81\x80' >> $out/lib/firmware/edid/virtual.bin
      printf '\xa9\xc0\x71\x4f\xb3\x00\x01\x01' >> $out/lib/firmware/edid/virtual.bin
      printf '\x01\x01\x01\x01\x01\x01\x02\x3a' >> $out/lib/firmware/edid/virtual.bin
      printf '\x80\x18\x71\x38\x2d\x40\x58\x2c' >> $out/lib/firmware/edid/virtual.bin
      printf '\x45\x00\x0f\x28\x21\x00\x00\x1e' >> $out/lib/firmware/edid/virtual.bin
      printf '\x00\x00\x00\xfd\x00\x38\x4b\x1e' >> $out/lib/firmware/edid/virtual.bin
      printf '\x51\x11\x00\x0a\x20\x20\x20\x20' >> $out/lib/firmware/edid/virtual.bin
      printf '\x20\x20\x00\x00\x00\xfc\x00\x56' >> $out/lib/firmware/edid/virtual.bin
      printf '\x69\x72\x74\x75\x61\x6c\x20\x48' >> $out/lib/firmware/edid/virtual.bin
      printf '\x44\x0a\x20\x20\x00\x00\x00\xff' >> $out/lib/firmware/edid/virtual.bin
      printf '\x00\x30\x30\x30\x30\x30\x30\x30' >> $out/lib/firmware/edid/virtual.bin
      printf '\x30\x30\x30\x30\x31\x0a\x00\xc0' >> $out/lib/firmware/edid/virtual.bin
    '')
  ];

  # Kernel-Parameter: EDID fuer alle DRM-Ausgaenge laden
  boot.kernelParams = [
    "drm.edid_firmware=edid/virtual.bin"
    "video=HDMI-A-1:e"  # HDMI-Ausgang aktivieren
  ];

  # NVIDIA Legacy 470 (GTX 760 / Kepler)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
  };

  # Xorg-Konfiguration fuer Headless GPU (virtueller Monitor)
  # Siehe RECHERSCHE.md fuer technische Details
  services.xserver.extraConfig = ''
    Section "Device"
        Identifier     "NVIDIA GPU"
        Driver         "nvidia"
        # BusID aus lspci: 01:00.0 -> PCI:1:0:0
        BusID          "PCI:1:0:0"
        # Erlaubt X-Start ohne physischen Monitor
        Option         "AllowEmptyInitialConfiguration" "True"
        # Erzwingt logische Monitor-Praesenz an HDMI
        Option         "ConnectedMonitor" "DFP-0"
        # Virtuelle EDID-Datei (1080p@60Hz)
        Option         "CustomEDID" "DFP-0:${virtualEdid}/edid.bin"
        # Verhindert Abschalten des virtuellen Ausgangs
        Option         "HardDPMS" "False"
    EndSection

    Section "Screen"
        Identifier     "Default Screen"
        Device         "NVIDIA GPU"
        Monitor        "Virtual Monitor"
        DefaultDepth   24
        SubSection "Display"
            Depth      24
            Modes      "1920x1080"
        EndSubSection
    EndSection

    Section "Monitor"
        Identifier     "Virtual Monitor"
        # Verhindert DPMS-Energiesparmodus
        Option         "DPMS" "False"
    EndSection
  '';

  # GNOME Desktop (Xorg, nicht Wayland wegen NVIDIA 470)
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
    # Initiales Passwort: changeme (beim ersten Login aendern!)
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoUXRrEIdgqYhCtpO5CxxBpyPtLtJ7a89zB+o6j/koD user@fedora"
    ];
    # Linger: User-Services starten beim Boot (nicht erst bei Login)
    # Kritisch fuer Sunshine, da es ein User-Service ist
    linger = true;
  };

  # Pakete
  environment.systemPackages = with pkgs; [
    kdenlive
    git
    distrobox
    pciutils
  ];

  # NVIDIA Persistence Mode - haelt GPU-Ressourcen aktiv
  # Verhindert Verzoegerungen beim Stream-Start
  systemd.services.nvidia-persistence = {
    description = "NVIDIA Persistence Mode";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.boot.kernelPackages.nvidiaPackages.legacy_470.bin}/bin/nvidia-smi -pm 1";
      RemainAfterExit = true;
    };
  };

  # Kdenlive Settings (klont kdenlive-portable-dots beim ersten Boot)
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

  # SSH fuer Remote-Management
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
