
---

# Proxmox Host & VM Setup Dokumentation

## 1. Vorbereitung auf dem Proxmox-Host

Bevor die VM erstellt wurde, musste der Host für das PCI-Passthrough der NVIDIA-Karte vorbereitet werden (IOMMU-Aktivierung).

* 
**PCI-Identifizierung**: Die GTX 760 wurde auf dem Bus `81:00` identifiziert.


* 
**USB-Passthrough**: Zwei spezifische Eingabegeräte (Maus/Tastatur) wurden vom Host direkt an die VM durchgereicht (`1c4f:0016` und `093a:2510`).



## 2. Erstellung der VM (ID 400)

Die VM wurde mit folgenden spezifischen Parametern angelegt, um Hardware-nahe Performance und UEFI-Kompatibilität zu garantieren:

* 
**General**: Name der VM ist `NixOS`.


* 
**OS**: Boot über das ISO `nixos-graphical-25.11...x86_64-linux.iso`. Der Gast-Typ ist Linux Kernel 2.6+ (`l26`).


* **System**:
* 
**Machine**: `q35` (optimiert für PCIe-Passthrough).


* 
**BIOS**: `OVMF (UEFI)`.


* 
**EFI-Disk**: Angelegt auf `local-lvm` mit `ms-cert=2023`.


* 
**SCSI-Controller**: `VirtIO SCSI single` für beste Performance.




* 
**CPU**: 8 Kerne (`cores: 8`) mit dem Typ `host`. Das stellt sicher, dass alle CPU-Features (wie AVX) an NixOS weitergegeben werden.


* 
**Memory**: 8 GB RAM (`8192 MB`).



## 3. Hardware-Anpassung für die Grafikkarte

Dies ist der entscheidende Teil für das GPU-Passthrough:

* **PCI-Device (hostpci0)**:
* Die ID `81:00` wurde zugewiesen.


* 
`pcie=1`: Die Karte wird als echte PCIe-Komponente behandelt.


* 
`x-vga=1`: Die Karte fungiert als **Primary GPU** für den Bootvorgang.




* 
**VGA**: Auf `none` gesetzt. Dadurch wird die emulierte Standard-Grafikkarte von Proxmox deaktiviert, sodass das Bildsignal ausschließlich aus der GTX 760 kommt.



## 4. Speicher & Netzwerk

* 
**Festplatte (scsi0)**: 40 GB Speicherplatz auf `local-lvm`, angebunden über `iothread=1` für schnellere I/O-Zugriffe.


* 
**Netzwerk**: `VirtIO` Bridge (`vmbr0`) mit aktivierter Firewall.



---

