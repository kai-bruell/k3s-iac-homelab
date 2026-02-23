# Fehlerbericht: Kernel Panic bei NixOS-VM mit Disk > ~2G auf Proxmox

## Zusammenfassung

NixOS-VMs, die via `nixos-anywhere` auf Proxmox installiert werden, starten nach der
Installation nicht, wenn die Disk größer als ~2G ist – es sei denn, in der Proxmox-VM
ist ein serieller Port (`serial_device`) konfiguriert.

**Symptom:** `Kernel panic - not syncing: Attempted to kill init! exit code=0x00000200`
**Ursache:** Fehlendes `serial_device` im QEMU/KVM-VM-Profil
**Fix:** `serial_device {}` im Terraform-Modul (bpg/proxmox Provider)

---

## Umgebung

| Komponente         | Version / Wert                        |
|--------------------|---------------------------------------|
| Hypervisor         | Proxmox VE                            |
| Terraform Provider | bpg/proxmox >= 0.70.0                 |
| Provisioning       | nixos-anywhere + disko                |
| NixOS              | 24.11 (Vicuna)                        |
| Bootstrap-Image    | Debian 12 Genericcloud (cloud-init)   |
| VM-Firmware        | SeaBIOS (BIOS-Boot, kein UEFI)        |
| Disk-Interface     | virtio-scsi-pci (`/dev/sda`)          |

---

## Symptom

Nach erfolgreicher Installation via `nixos-anywhere` bootet die VM nicht in das
installierte NixOS-System. Im seriellen Konsolen-Output (`qm terminal <vmid>`) erscheint:

```
Kernel panic - not syncing: Attempted to kill init! exit code=0x00000200
```

`exit code=0x00000200` bedeutet: systemd (PID 1) hat mit Exit-Status 2 beendet.
Dies geschieht in **Stage 2** (nach dem initrd-Übergang), d.h. das Root-Filesystem
wurde erfolgreich gemountet, aber systemd selbst crasht bei der Initialisierung.

---

## Reproduktion

### Voraussetzungen
- Proxmox-VM mit Debian-cloud-init-Bootstrap (Template VM 9000)
- Disk-Größe: **> 2G** (z.B. 20G)
- Terraform-Modul **ohne** `serial_device {}`
- NixOS-Flake mit `qemu-guest.nix`-Profil

### Schritte
1. Template ohne `qm resize` erstellen (2G)
2. Terraform-Modul **ohne** `serial_device {}` deployen
3. nixos-anywhere läuft durch – **kein Fehler**
4. VM bootet neu
5. **Kernel Panic** erscheint

### Beobachteter Unterschied nach Disk-Größe

| Disk-Größe | `serial_device` | Ergebnis       |
|------------|-----------------|----------------|
| ~2G        | nein            | ✅ Funktioniert (Glück) |
| 20G        | nein            | ❌ Kernel Panic |
| 20G        | ja              | ✅ Funktioniert |
| 20G (nach Provisioning manuell resizen) | nein | ✅ Funktioniert |

---

## Untersuchte und ausgeschlossene Ursachen

| Theorie                                  | Ausgeschlossen weil                                        |
|------------------------------------------|------------------------------------------------------------|
| NVIDIA-Treiber ohne GPU                  | Panic nach Auskommentieren von NVIDIA-Config weiterhin     |
| Kaputtes/resiztes Proxmox-LVM-Template   | Mehrfach neu erstellt, gleiches Ergebnis                   |
| Proxmox Thin-Pool voll                   | `lvs` zeigt 11,54% Auslastung (~15,7GB von 136GB)          |
| `boot.growPartition = true`              | Nach Auskommentieren weiterhin Panic                       |
| Resize-Methode (qm resize vs qemu-img)   | Beide Methoden → gleicher Panic                            |
| Disk-Größe als direkter Trigger          | Red Herring – eigentliche Ursache ist `serial_device`      |
| `boot.kernelParams = ["console=ttyS0"]`  | Hat keinen Einfluss – Panic tritt ohne `serial_device` auf |

---

## Ursache

Ohne `serial_device {}` in der Proxmox-VM-Konfiguration emuliert QEMU **keinen
16550A UART** (serielle Schnittstelle). Dies hat folgende Auswirkungen:

1. **Veränderte ACPI-Tabellen:** Die ACPI-Hardwarebeschreibung der VM enthält keinen
   seriellen Port. Linux enumeriert dadurch Devices in einer anderen Reihenfolge.

2. **Race Condition in systemd Stage 2:** Die veränderte Device-Enumeration führt zu
   einem Timing-Problem bei der Console-/Device-Initialisierung von systemd (PID 1).
   Systemd beendet sich mit Exit-Code 2 → Kernel Panic.

3. **Disk-Größe als Timing-Faktor:** Auf einer kleinen (~2G) Disk ist die Device-
   Enumeration schnell genug, dass die Race Condition in den meisten Fällen nicht
   auftritt. Ab ~20G ist sie reproduzierbar.

4. **nixos-anywhere läuft fehlerfrei durch:** Die Installation selbst ist korrekt.
   Der Fehler tritt erst beim ersten Boot des installierten Systems auf.

---

## Fix

### Terraform-Modul (`terraform/modules/nixos-vm/main.tf`)

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  # ...

  # Serieller Port: verhindert Kernel Panic durch ACPI-Race-Condition
  # Ohne diesen Block bootet NixOS auf Disks > ~2G nicht.
  serial_device {}

  # ...
}
```

### Optional: Kernel-Output auf serieller Konsole sichtbar machen

Für vollständigen Boot-Output via `qm terminal <vmid>` zusätzlich in
`nixos/modules/hardware-vm.nix`:

```nix
boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];
```

Ohne diesen Parameter bootet das System korrekt, aber `qm terminal` zeigt keinen
Kernel-Output (nur den systemd-Output, sobald ttyS0 als Getty bereit ist).

---

## Debugging-Methode

Seriellen Port in Proxmox aktivieren:
```bash
# Auf Proxmox-Host:
qm terminal <vmid>   # Ctrl+O zum Beenden
```

Voraussetzung: `serial_device {}` im Terraform-Modul UND VM läuft.

---

## Zeitachse der Untersuchung

- Erster Kernel Panic: nach versehentlichem `qm resize 9000 scsi0 +30G` (doppelt ausgeführt → 63G)
- Mehrfache Template-Neuerstellung ohne Erfolg
- 2G-Template ohne Resize: funktioniert → Disk-Größe als Ursache angenommen (falsch)
- `boot.growPartition` deaktiviert → kein Effekt
- Thin-Pool-Auslastung geprüft → kein Effekt
- Serielle Konsole hinzugefügt (`serial_device {}` + `boot.kernelParams`) → funktioniert
- `boot.kernelParams` entfernt → funktioniert weiterhin ✅
- `serial_device {}` entfernt → Kernel Panic ✅ reproduziert
- `serial_device {}` wieder hinzugefügt → funktioniert ✅ **Ursache bestätigt**
