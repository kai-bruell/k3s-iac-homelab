## 1. Die Kernel-Hürde (Kritisch)

Wie in deiner Dokumentation beschrieben, lässt sich der NVIDIA 470er-Treiber auf Kernel-Versionen ab 6.11 nicht mehr kompilieren. NixOS macht es dir jedoch sehr einfach, auf einen älteren **LTS-Kernel** (z. B. 6.6) zu wechseln, was für die Stabilität deiner GPU zwingend erforderlich ist.

## 2. NixOS Konfiguration (`configuration.nix`)

In NixOS konfigurierst du das gesamte System deklarativ. Um die GTX 760 zum Laufen zu bringen, musst du folgende Anpassungen vornehmen:

### Kernel & Treiber-Setup

Du musst den Kernel auf die Version 6.6 festlegen und den spezifischen Legacy-Treiber erzwingen:

```nix
{ config, pkgs, ... }:

{
  # 1. Kernel auf 6.6 LTS festlegen (wichtig für Treiber-Kompatibilität)
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # 2. NVIDIA Treiber aktivieren
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = {
    # 3. Den Legacy-Zweig 470 auswählen
    package = config.boot.kernelPackages.nvidia_x11_legacy470;
    
    # Modesetting ist für Wayland/moderne Setups oft nötig
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false; # Kepler unterstützt keine Open-Source Kernel-Module
  };
}

```

## 3. Alternative: Der "Nouveau" Weg

Falls du einen aktuellen Kernel nutzen möchtest (z. B. den Standard-Kernel von NixOS 24.11+), kannst du den **Nouveau**-Treiber mit **NVK** nutzen.

* **Vorteil:** Funktioniert mit jedem Kernel.
* **Nachteil:** Du musst das Reclocking manuell handhaben, da die Karte sonst sehr langsam taktet.
* **Mesa-Version:** Stelle sicher, dass du mindestens **Mesa 25.2** nutzt, um Vulkan 1.2 Support zu erhalten.

## 4. VM-Hardware-Profil (Proxmox)

Damit NixOS die Hardware korrekt erkennt, stelle sicher, dass deine VM-Konfiguration in Proxmox exakt den Anforderungen entspricht:

* **Machine:** `q35`
* **BIOS:** `OVMF (UEFI)`
* **PCI Device:** ID `81:00` (All Functions & PCI-Express aktiviert)

---

