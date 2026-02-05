# Diagnose: GNOME auf NVIDIA GPU (Headless/Passthrough)

## Ziel
NixOS VM mit GPU-Passthrough (NVIDIA GTX 760), GNOME Desktop, Sunshine Remote Streaming mit NVENC Hardware-Encoding.

## Aktueller Stand

### Was funktioniert
- **VM bootet** erfolgreich (NixOS 24.11, Kernel 6.6 LTS)
- **GPU Passthrough** funktioniert - GPU wird erkannt:
  ```
  lspci | grep -i nvidia
  01:00.0 VGA compatible controller: NVIDIA Corporation GK104 [GeForce GTX 760]
  02:00.0 Audio device: NVIDIA Corporation GK104 HDMI Audio Controller
  ```
- **NVIDIA Treiber** (470 Legacy) geladen:
  ```
  lsmod | grep nvidia
  nvidia_drm, nvidia_modeset, nvidia_uvm, nvidia (40MB)
  ```
- **SSH** funktioniert
- **Sunshine** ist erreichbar (Port 47990) nach manuellem Start
- **Moonlight** kann sich verbinden und streamt (zeigt aber nur blinkenden Cursor)

### Was NICHT funktioniert
- **GNOME Desktop startet nicht** - nur blinkender Cursor sichtbar
- **Sunshine startet nicht automatisch** - muss manuell gestartet werden:
  ```bash
  systemctl --user start sunshine
  ```
  Ursache: Sunshine ist ein User-Service, startet erst bei Login. Da GNOME crasht, gibt es keine vollstaendige User-Session.
- **Xorg crasht** mit folgendem Fehler:
  ```
  xf86EnableIO: failed to enable I/O ports 0000-03ff (Operation not permitted)
  (EE) No devices detected.
  Fatal server error:
  (EE) no screens found(EE)
  ```

## Ursachenanalyse

### Kernproblem
Die NVIDIA GPU hat **keinen Monitor angeschlossen**. Ohne physisches Display (oder Emulation davon):
1. GPU initialisiert keinen Framebuffer
2. Xorg findet keine "Screens"
3. GDM/GNOME kann nicht starten
4. Sunshine kann nur schwarzes Bild/Cursor capturen

### Warum passiert das?
Bei GPU-Passthrough wird die physische GPU direkt an die VM durchgereicht. Die GPU verhält sich exakt wie in einem echten PC - ohne Monitor kein Display-Output.

### Getestete Loesungen (gescheitert)

#### 1. EDID Hack (Virtual Display)
```nix
services.xserver.extraConfig = ''
  Section "Device"
      Option "AllowEmptyInitialConfiguration" "True"
      Option "ConnectedMonitor" "DFP-0"
      Option "CustomEDID" "DFP-0:/etc/nixos/edid.bin"
  EndSection
'';
```
**Ergebnis:** Xorg ignoriert die Config, "No devices detected" bleibt.

#### 2. x-vga=true (GPU als primaeres Display)
```hcl
# In Terraform hostpci Block
xvga = true
```
**Ergebnis:** VM bootet nicht mehr, haengt beim Start.

#### 3. Wayland deaktivieren
```nix
services.xserver.displayManager.gdm.wayland = false;
```
**Ergebnis:** Hilft nicht, da Xorg selbst crasht (nicht Wayland).

#### 4. Virtuelles VGA (std) aktivieren
```hcl
vga_type = "std"
```
**Ergebnis:** Proxmox Console funktioniert, aber Xorg versucht trotzdem NVIDIA zu nutzen und crasht.

## Loesungsoptionen

### Option A: Dummy HDMI Plug (Empfohlen)
**Hardware-Loesung:** Kleiner Stecker (~5 EUR) der in den HDMI/DP-Port der GPU gesteckt wird.

**Vorteile:**
- Simuliert echten Monitor (EDID wird von GPU gelesen)
- GPU initialisiert Framebuffer korrekt
- Xorg/GNOME starten normal
- NVENC funktioniert fuer Sunshine
- Saubere, zuverlaessige Loesung

**Nachteile:**
- Erfordert physischen Zugang zum Server
- Kostet ~5 EUR

### Option B: Modesetting-Treiber fuer Display
```nix
services.xserver.videoDrivers = [ "modesetting" ];
```
**Idee:** Xorg nutzt virtuelles VGA fuer Display, NVIDIA nur fuer Encoding.

**Vorteile:**
- Kein Hardware-Kauf noetig
- Desktop funktioniert

**Nachteile:**
- NVENC fuer Sunshine funktioniert vermutlich NICHT (Xorg nicht auf NVIDIA)
- Kdenlive GPU-Rendering funktioniert nicht
- Verfehlt das eigentliche Ziel

### Option C: Virtual Display Driver (Komplex)
Spezielle Software die einen virtuellen Monitor erstellt (z.B. `xserver-xorg-video-dummy`, NVIDIA Virtual Display).

**Status:** Nicht getestet, erfordert weitere Recherche fuer NixOS.

## Empfehlung

**Dummy HDMI Plug bestellen.** Das ist die einzige Loesung die das Ziel (GNOME auf NVIDIA mit NVENC) zuverlaessig erreicht.

Beispiel-Produkte:
- "HDMI Dummy Plug" auf Amazon (~5-10 EUR)
- Unterstuetzt typischerweise bis 4K@60Hz
- Kleine Adapter die wie USB-Sticks aussehen

## Technische Details

### VM Konfiguration
- **Proxmox:** bpg/proxmox Terraform Provider
- **Machine Type:** q35 (fuer PCIe Passthrough)
- **BIOS:** SeaBIOS (GRUB Bootloader)
- **GPU:** hostpci0 mit pcie=1, rombar=1

### NixOS Konfiguration
- **Kernel:** 6.6 LTS (fuer Legacy-Treiber Kompatibilitaet)
- **NVIDIA:** 470.256.02 (Legacy fuer Kepler/GTX 760)
- **Desktop:** GNOME 47 mit GDM
- **Streaming:** Sunshine (systemd user service)

### Relevante Dateien
- `terraform/environments/video-editing/main.tf` - VM Definition
- `terraform/environments/video-editing/terraform.tfvars` - VM Parameter
- `terraform/environments/video-editing/nixos/configuration.nix` - NixOS Config
- `.github/workflows/build-nixos-image.yml` - CI/CD Pipeline

## Bekannte Fixes (noch umzusetzen)

### Sunshine Autostart
Sunshine ist ein User-Service und startet nur bei vollstaendiger User-Session. Fix: Lingering aktivieren damit User-Services bei Boot starten:

```nix
# In configuration.nix hinzufuegen:
users.users.user.linger = true;
```

Dies startet `systemctl --user` Services fuer "user" beim Boot, auch ohne Login.

## Naechste Schritte
1. [ ] Dummy HDMI Plug bestellen
2. [ ] Plug in GPU HDMI-Port stecken
3. [ ] `users.users.user.linger = true;` in configuration.nix hinzufuegen
4. [ ] Neues Image bauen und deployen
5. [ ] VM neu starten
6. [ ] Testen ob GNOME startet
7. [ ] Sunshine/Moonlight Verbindung testen mit GPU-Encoding
