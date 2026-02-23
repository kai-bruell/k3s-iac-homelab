
# Analyse der ACPI-induzierten Initialisierungsfehler in virtualisierten NixOS-Umgebungen unter Proxmox VE

## Die Architektur der Hardware-Abstraktion in modernen Hypervisoren

Die Bereitstellung von Betriebssystemen in virtualisierten Umgebungen basiert auf einer komplexen Orchestrierung zwischen der Hardware-Emulationsschicht des Hypervisors und den Hardware-Erkennungsmechanismen des Gast-Kernels. In der Welt von **Proxmox VE**, einer Plattform, die maßgeblich auf **QEMU** (Quick Emulator) und **KVM** (Kernel-based Virtual Machine) aufbaut, wird diese Kommunikation primär über die **Advanced Configuration and Power Interface (ACPI)** Tabellen abgewickelt.

ACPI fungiert hierbei als das verbindende Gewebe, das dem Gast-Betriebssystem mitteilt, welche Hardware-Ressourcen vorhanden sind, wie sie adressiert werden und welche Interrupts sie nutzen. Ein scheinbar triviales Detail wie die Konfiguration eines seriellen Ports kann dabei weitreichende Konsequenzen für die Stabilität des Boot-Prozesses haben, insbesondere wenn moderne Init-Systeme wie **systemd** und automatisierte Installations-Frameworks wie **NixOS mit Disko** zum Einsatz kommen.

Das Phänomen, dass eine NixOS-VM nach der Installation via `nixos-anywhere` bei einer Festplattengröße von mehr als ca. **2 GB** reproduzierbar in eine **Kernel Panic** läuft, sofern kein `serial_device` definiert ist, weist auf eine tiefgreifende Inkonsistenz in der zeitlichen Abfolge der Hardware-Initialisierung hin. Der resultierende Fehlercode `exit code=0x00000200 (Status 2)` deutet darauf hin, dass der systemd-Prozess (PID 1) unmittelbar nach dem Übergang von der Initrd (Stage 1) zum eigentlichen System (Stage 2) aufgrund fehlender oder nicht erreichbarer Standard-I/O-Ressourcen terminiert.

| Komponente der virtuellen Maschine | Rolle im ACPI-Kontext | Relevanz für den Boot-Prozess |
| --- | --- | --- |
| **16550A UART (Seriell)** | Definition via `PNP0501` | Bereitstellung der Standardkonsole `/dev/ttyS0` |
| **fw_cfg Device** | Definition via `QEMU0002` | Transfer von Konfigurationstabellen vom Host zum Gast |
| **VirtIO SCSI Controller** | PCI-Enumeration | Zugriff auf das Root-Dateisystem und Partitionstabellen |
| **SeaBIOS / OVMF** | Firmware-Initialisierung | Aufbau der initialen ACPI-Tabellenstruktur |

---

## Historische und technische Relevanz des 16550A UART in virtuellen Umgebungen

Obwohl die serielle Schnittstelle (UART) aus der physischen Desktop-Hardware weitgehend verschwunden ist, bleibt sie in der Server-Virtualisierung eine der verlässlichsten Methoden für das Logging und das Out-of-Band-Management. In QEMU wird ein serieller Port standardmäßig als **ISA-Gerät** emuliert. Wenn ein Administrator in Proxmox kein `serial_device` explizit konfiguriert, unterlässt QEMU die Emulation des 16550A-Controllers vollständig. Dies führt dazu, dass der entsprechende Eintrag in der **Differentiated System Description Table (DSDT)** der ACPI-Struktur fehlt.

Die Abwesenheit dieses Eintrags hat zur Folge, dass der Linux-Kernel während der frühen Boot-Phase keinen `8250_pnp`-Treiber für die Adresse `0x3F8` lädt. In einer Standard-NixOS-Konfiguration, die häufig Parameter wie `console=ttyS0` enthält oder implizit davon ausgeht, dass eine serielle Konsole für Systemd-Meldungen verfügbar ist, entsteht dadurch ein Vakuum in der I/O-Kette.

---

## Die Anatomie des Systemd-Crashs (Exit Status 2)

Wenn der Linux-Kernel die Kontrolle an den Init-Prozess übergibt, erwartet dieser eine stabile Umgebung für die Initialisierung von User-Space-Diensten. Systemd (PID 1) übernimmt in NixOS in Stage 2 die Aufgabe, das System in den gewünschten Zielzustand (Target) zu führen. Der Fehler `Attempted to kill init! exit code=0x00000200` bedeutet, dass systemd mit dem **Status 2** beendet wurde.

### Ursachenanalyse für den Statuscode 2

In der Linux-Systemprogrammierung steht ein Exit-Status von 2 oft für einen Fehler bei der Verwendung von Shell-Builtins oder, im Falle von binären Programmen wie systemd, für einen schwerwiegenden Dateifehler oder eine fehlerhafte Umgebungsspezifikation. Im Kontext des Boot-Vorgangs tritt dieser Fehler auf, wenn systemd versucht, seine Standard-Streams (stdin, stdout, stderr) zu öffnen und dabei auf ein nicht existierendes Gerät oder einen E/A-Fehler stößt.

Besonders kritisch ist hierbei der Zugriff auf `/dev/console`. Wenn der Kernel über ACPI keine serielle Hardware gefunden hat, aber systemd angewiesen wurde, diese zu nutzen, führt der Versuch, das Terminal zu initialisieren, zu einem fatalen Fehler. Da PID 1 niemals beendet werden darf, reagiert der Kernel auf diesen Exit mit einer Panik, um eine inkonsistente Systemumgebung zu verhindern.

Mathematisch lässt sich die Wahrscheinlichkeit eines solchen Crashs als Funktion der Verfügbarkeit von Gerätedateien  und der Zeit  beschreiben. Wenn  zum Zeitpunkt  nicht definiert ist, gilt:

wobei  die Zeit ist, die der udev-Daemon benötigt, um die notwendigen Gerätedateien basierend auf der Hardware-Erkennung anzulegen. Ohne ACPI-Eintrag für den seriellen Port wird  niemals definiert, was die Panic unausweichlich macht, sobald systemd darauf zugreift.

---

## Die Rolle der Festplattengröße als Latenz-Katalysator

Ein zentrales Rätsel des vorliegenden Falls ist die Beobachtung, dass der Fehler erst bei Festplattenkapazitäten von mehr als ca. 2 GB auftritt. Dies legt nahe, dass die Festplattengröße kein direkter Auslöser, sondern ein Faktor ist, der das Timing des Boot-Vorgangs so verändert, dass eine latente **Race Condition** zwischen der Hardware-Erkennung und der Initialisierung von systemd manifest wird.

### GPT-Metadaten und Scan-Zeiten

Moderne Partitionstabellen im **GPT-Format** (GUID Partition Table) speichern eine Kopie des Headers am Ende des Datenträgers. Bei der Initialisierung eines Blockgeräts muss der Kernel sowohl den primären Header am Anfang als auch den Backup-Header am Ende lesen und verifizieren. Bei einer virtuellen Festplatte von 2 GB liegen diese Sektoren physikalisch nah beieinander, und die E/A-Latenz ist minimal.

Bei einer 20 GB oder 100 GB großen Festplatte erhöht sich die Zeit für das Aufsuchen des Backup-Headers, insbesondere bei Thin-Provisioning-Speichern wie LVM-Thin oder ZFS-basierten Proxmox-Pools. Wenn die Festplatte während des ersten Boots nach einer `nixos-anywhere` Installation vergrößert wurde oder wenn `systemd-growfs` versucht, die Partition zu erweitern, entstehen zusätzliche E/A-Warteschlangen.

| Disk-Kapazität | E/A-Latenz für GPT-Verify | Udev-Event-Generierung | Race-Condition-Fenster |
| --- | --- | --- | --- |
| **< 2 GB** | Niedrig | Nahezu instantan | Sehr schmal (oft unbemerkt) |
| **20 GB** | Mittel | Verzögert durch Seek-Zeiten | Breit (Reproduzierbar) |
| **> 100 GB** | Hoch | Signifikant verzögert | Sehr breit |

Diese Verzögerung führt dazu, dass die Hardware-Enumeration der Festplatte und ihrer Partitionen länger dauert. Wenn gleichzeitig der ACPI-Eintrag für den seriellen Port fehlt, gerät die gesamte Reihenfolge der Device-Node-Erstellung in `/dev` durcheinander. Das System "rast" durch die ACPI-basierte Initialisierung (da Hardware fehlt), trifft dann aber auf eine Verzögerung bei der Blockgerät-Initialisierung. Dieser Versatz führt dazu, dass systemd versucht, seine Stage-2-Logik (einschließlich Filesystem-Mounts und Konsolenzugriff) auszuführen, bevor der Kernel oder udev die Umgebung stabilisiert haben.

### Der Effekt von systemd-growfs

Ein weiterer kritischer Punkt ist die automatisierte Erweiterung des Dateisystems auf die volle Partitionsgröße, ein Standardverhalten bei Cloud-Images und NixOS-Installationen via Disko. Der Dienst `systemd-growfs` benötigt stabilisierte `/dev/block/`-Symlinks. Wenn dieser Dienst aufgrund von Timing-Problemen beim Zugriff auf das Blockgerät scheitert und systemd dies als kritischen Fehler einstuft, kann dies ebenfalls zum Exit-Status 2 führen. Ohne seriellen Port hat systemd keine Möglichkeit, diesen Fehler sinnvoll zu protokollieren, was den Absturz beschleunigt.

---

## Infrastruktur-as-Code: Die Terraform-Perspektive

In modernen DevOps-Workflows wird Proxmox häufig über den `bpg/proxmox` Terraform-Provider verwaltet. Die Standardeinstellungen dieses Providers spiegeln oft eine minimale VM-Konfiguration wider, um maximale Flexibilität zu gewährleisten. Wenn jedoch das Attribut `serial_device` ausgelassen wird, erzeugt der Provider eine VM-Konfiguration ohne UART-Emulation.

### Analyse der Provider-Konfiguration

Ein typisches Terraform-Modul für eine NixOS-VM könnte wie folgt strukturiert sein:

```hcl
resource "proxmox_virtual_environment_vm" "nixos_vm" {
  name      = "nixos-server"
  node_name = "pve-node-01"
  
  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "virtio0"
    size         = 20
  }

  # Das Fehlen dieses Blocks führt zur Kernel Panic bei NixOS
  serial_device {}
}

```

Interessanterweise bemerkt der Administrator während der Installation via `nixos-anywhere` keinen Fehler, da das Installations-Image (oft ein kexec-basierter Kernel) eine eigene, hochgradig optimierte Hardware-Erkennung mitbringt und nicht zwingend auf die ACPI-DSDT-Tabellen der Ziel-VM angewiesen ist. Erst beim Neustart in das installierte NixOS-System, welches die Standard-NixOS-Boot-Pipeline nutzt, schlägt die fehlende Hardware-Synchronisation zu.

### Die Bedeutung der Hardware-ID PNP0501

Wenn der Block `serial_device {}` vorhanden ist, fügt QEMU der ACPI-Beschreibung die ID **PNP0501** hinzu. Dies signalisiert dem Gast-Kernel die Existenz eines Standard-UARTs. Dies stabilisiert die Device-Enumeration, da der Kernel nun eine feste Referenz für I/O-Operationen hat. Selbst wenn die Festplatte groß ist und der GPT-Scan zusätzliche Zeit in Anspruch nimmt, sorgt die Anwesenheit des seriellen Ports dafür, dass der Konsolen-Stack des Kernels korrekt initialisiert wird, bevor systemd das Kommando übernimmt.

---

## Die NixOS-spezifische Boot-Phase (Stage 1 & Stage 2)

NixOS unterscheidet sich in seiner Boot-Architektur von konventionellen Distributionen durch die strikte Trennung in zwei Phasen. Stage 1 ist eine initiale RAM-Disk (initrd), die das Root-Dateisystem sucht und mountet. Stage 2 ist das eigentliche System, das durch ein Shell-Skript (`/nix/store/...-stage-2-init`) eingeleitet wird.

### Empfindlichkeit der Stage 2

In Stage 2 wird die Kontrolle von dem minimalen Stage-1-Skript an systemd übergeben. Dieser Übergang ist der Moment, in dem der Fehler auftritt. Wenn das Root-Dateisystem erfolgreich gemountet wurde (was der Fall ist, da die Stage 1 bereits abgeschlossen wurde), versucht das Stage-2-Skript, die Umgebung für systemd vorzubereiten. Hierzu gehört das Binden von Standard-Dateideskriptoren an `/dev/console`.

Wenn die ACPI-Datenbank keinen seriellen Port gemeldet hat, ist `/dev/console` unter Umständen nicht korrekt mit einer physischen oder virtuellen TTY-Instanz verbunden. Das Resultat ist ein sofortiger Abbruch von systemd beim Versuch, die Logging-Infrastruktur zu starten. Da NixOS-Konfigurationen oft das Modul `profiles/qemu-guest.nix` enthalten, wird implizit erwartet, dass Standard-KVM-Geräte vorhanden sind.

### Mathematische Modellierung der Boot-Latenz

Die Verzögerung bei der Blockgerät-Erkennung lässt sich näherungsweise durch die Summe der Initialisierungszeiten der verschiedenen Schichten beschreiben:

Dabei ist  bei einer 20-GB-Platte signifikant höher als bei einer 2-GB-Platte, da der Lesekopf (oder dessen virtuelle Entsprechung) an das Ende des Adressraums springen muss. In einer virtualisierten Umgebung mit einem Thin-Pool muss der Hypervisor zudem erst die entsprechenden Blöcke am Ende der virtuellen Disk allozieren oder aus dem Metadaten-Cache laden.

Nehmen wir an, systemd startet seine Initialisierung bei . Damit der Boot erfolgreich ist, muss gelten:

Ohne seriellen Port im ACPI wird  unendlich oder undefiniert, was zu einem sofortigen Fehler führt. Mit seriellen Port ist  fast unmittelbar nach  erreicht, wodurch die Bedingung immer erfüllt ist, unabhängig von der Dauer von .

---

## Vergleich mit anderen Hypervisoren und Distributionen

Das Problem scheint spezifisch für die Kombination aus Proxmox (QEMU), NixOS und systemd zu sein. Andere Distributionen wie Debian oder Ubuntu fangen fehlende serielle Konsolen oft eleganter ab, indem sie auf einen VGA-Fallback umschalten oder den Boot-Vorgang mit einer Warnung fortsetzen. NixOS hingegen legt großen Wert auf eine deterministische Hardware-Beschreibung. Wenn die Konfiguration (z.B. durch `qemu-guest.nix`) eine bestimmte Hardware-Umgebung suggeriert, die ACPI-Daten jedoch widersprüchlich sind, führt dies zu den beobachteten Instabilitäten.

| Hypervisor | Standard-ACPI-Verhalten | NixOS-Kompatibilität |
| --- | --- | --- |
| **Proxmox (QEMU)** | Minimalistisch, manuelles Hinzufügen nötig | Erfordert explizites `serial_device` |
| **VMware ESXi** | Reichhaltiges Standard-ACPI | Meist unproblematisch |
| **VirtualBox** | Standardmäßig aktivierte serielle Ports | Meist unproblematisch |
| **Bare Metal** | Hardware ist immer via ACPI/DSDT präsent | Stabil |

---

## Untersuchung ausgeschlossener Faktoren

Im Zuge der Fehlerdiagnose wurden verschiedene alternative Theorien geprüft und verworfen. Die Hypothese, dass der Proxmox-Thin-Pool voll sein könnte, wurde durch die Analyse von `lvs` widerlegt, die eine Auslastung von lediglich ca. 11,5 % zeigte. Ebenso konnte ausgeschlossen werden, dass NVIDIA-Grafiktreiber ohne vorhandene GPU den Panic verursachen, da das Problem auch nach Entfernung der entsprechenden Konfigurationen bestehen blieb.

Entscheidend war auch die Erkenntnis, dass `boot.kernelParams = ["console=tty0"]` allein das Problem nicht löst, wenn die Hardware-Emulation fehlt. Dies bestätigt, dass es sich nicht um ein reines Software-Konfigurationsproblem handelt, sondern um eine fundamentale Inkonsistenz in der Hardware-Deskription gegenüber dem Betriebssystem-Kernel.

---

## Synthese der Ergebnisse und Empfehlungen

Die tiefgehende Analyse der Boot-Prozesse von NixOS auf Proxmox VE führt zu einem klaren Ergebnis: Die Konfiguration eines seriellen Geräts ist keine optionale Annehmlichkeit, sondern eine strukturelle Notwendigkeit für die Stabilität des Systems, sobald die Festplattenkapazitäten über ein minimales Maß hinausgehen.

### Der Fix: Terraform und NixOS-Konfiguration

Um eine zuverlässige Bereitstellung zu gewährleisten, muss der `serial_device {}` Block in das Terraform-Modul integriert werden. Dies stellt sicher, dass QEMU die notwendigen ISA-Ressourcen emuliert und der ACPI-DSDT die ID **PNP0501** hinzufügt.

Darüber hinaus empfiehlt es sich, die Kernel-Parameter in NixOS so zu konfigurieren, dass sie sowohl die serielle Konsole als auch die Standard-VGA-Konsole unterstützen:

```nix
boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

```

Diese Reihenfolge sorgt dafür, dass Boot-Meldungen primär an den seriellen Port gesendet werden (was für `qm terminal` nützlich ist), während `tty0` als Fallback für die grafische Konsole dient. Durch das Vorhandensein beider Konsolen-Definitionen in Kombination mit der korrekten ACPI-Hardware-Beschreibung wird die Race Condition effektiv neutralisiert. Das Init-System findet nun in jedem Fall eine gültige Konsole vor, unabhängig davon, wie lange die Blockgerät-Enumeration bei großen Festplatten dauert.

## Zusammenfassende Schlussfolgerung

Die beobachtete Kernel Panic ist ein klassisches Beispiel für die Komplexität moderner Hardware-Software-Schnittstellen. Die scheinbare Korrelation mit der Festplattengröße diente als wichtiger Hinweis auf ein Timing-Problem, dessen wahre Ursache jedoch in der unvollständigen ACPI-Beschreibung der virtualisierten Hardware lag. Die Implementierung eines seriellen Geräts behebt diesen Mangel, indem sie eine konsistente und erwartungskonforme Hardware-Umgebung schafft, die den Anforderungen von systemd in der kritischen Stage-2-Initialisierung von NixOS gerecht wird. Damit ist der Fehler nicht nur korrigiert, sondern in seiner mechanischen Ursache vollständig verstanden.

---

