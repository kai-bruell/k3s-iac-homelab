Das ist eine hervorragende Idee. Wenn du das **Deep Research** Modul fütterst, braucht es eine präzise Hypothese, um die richtigen Ecken des Internets (Kernel-Mailinglisten, systemd-Issues, QEMU-Patches) zu durchkämmen.

Hier ist die Zusammenfassung der technischen Vermutung für deine Unterlagen:

---

## Hypothese: Die "Serial-ACPI-Timing" Race Condition

### 1. Die Hardware-Ebene (QEMU/Proxmox)

Ohne die Definition eines `serial_device` lässt der QEMU-Prozess die Emulation des **16550A UART-Controllers** komplett weg. Dies verändert nicht nur die verfügbare Hardware, sondern modifiziert die **ACPI-Tabellen** (Advanced Configuration and Power Interface), die dem Betriebssystem beim Booten übergeben werden.

### 2. Die Kernel-Ebene (NixOS / Linux)

Der Linux-Kernel liest diese ACPI-Tabellen, um Geräte zu enumerieren.

* **Mit Serial-Device:** Der Kernel findet den UART-Port früh, weist ihm Ressourcen zu und stabilisiert die Device-Liste.
* **Ohne Serial-Device:** Die Hardware-Liste ist kürzer. Der Kernel "rast" schneller durch die Initialisierung der verbleibenden Komponenten.

### 3. Der Trigger: Disk-Größe (> 2GB) als Latenz-Faktor

Die Beobachtung, dass es bei **2GB funktioniert**, aber bei **20GB scheitert**, deutet auf ein **Timing-Problem** hin:

* Größere virtuelle Disks (insbesondere bei SCSI/VirtIO) benötigen minimal mehr Zeit für die Registrierung der Partitionen oder das Laden der Metadaten im Kernel.
* In Kombination mit der durch das fehlende `serial_device` veränderten ACPI-Enumeration entsteht eine **Race Condition**.

### 4. Der Crash: systemd (PID 1) Exit Code 2

In **Stage 2** übernimmt systemd die Kontrolle. Systemd versucht, Standard-Streams (`stdin`, `stdout`, `stderr`) und TTYs zu mappen.

* Wenn die ACPI-Tabelle keinen seriellen Port vorsieht, das System aber (vielleicht durch Standard-Configs in NixOS) erwartet, dass eine Konsole vorhanden ist oder die Device-Nodes in einer bestimmten Reihenfolge erscheinen, läuft systemd in einen fatalen Fehler.
* **Exit-Code 0x00000200 (2)** bedeutet bei systemd oft ein "I/O Error" oder "File not found" beim Zugriff auf essentielle Gerätedateien (`/dev/console` oder ähnliche). Da PID 1 nicht sterben darf, quittiert der Kernel dies mit einer **Kernel Panic**.

---

### Checkliste für Deep Research

1. "systemd exit code 2 stage 2 nixos qemu"
2. "QEMU ACPI table changes without serial port causing kernel panic"
3. "virtio-scsi disk size affecting device enumeration timing linux"
4. "NixOS 24.11 systemd PID 1 failure without ttyS0"

