### Technisches Referenzmodell für die Implementierung von Headless-GPU-Szenarien unter NixOS mit NVIDIA-Legacy-Architekturen

Die Virtualisierung von Grafikressourcen und der Betrieb von leistungsfähigen Grafikprozessoren (GPUs) in kopflosen (headless) Umgebungen stellen eine der komplexesten Herausforderungen innerhalb der Linux-Systemadministration dar. Insbesondere die Verwendung von Consumer-Hardware, wie der NVIDIA GeForce GTX 760 auf Basis der Kepler-Architektur unter Verwendung des Legacy-Treibers der Version 470, erfordert tiefgehende Eingriffe in die Schichten des Grafik-Stacks. Während professionelle Lösungen wie NVIDIA Tesla- oder Quadro-Karten nativ für den Betrieb in Rechenzentren ohne physische Anzeige konzipiert sind, implementiert NVIDIA in seinen Consumer-Treibern künstliche Hürden, die eine Initialisierung der GPU ohne angeschlossenen Monitor erschweren oder verhindern. Dieses Dokument analysiert die theoretischen Grundlagen des Xorg-Servers, die Mechanismen der Extended Display Identification Data (EDID) und die spezifischen Implementierungspfade innerhalb des deklarativen Ökosystems von NixOS, um einen stabilen Betrieb für Streaming-Dienste wie Sunshine zu gewährleisten.   

## Die Architektur des X-Servers und das Problem der Monitor-Erkennung

Der Xorg-Server fungiert als zentrale Abstraktionsschicht zwischen der physischen Grafikhardware und der Desktop-Umgebung, in diesem Fall GNOME. Seine primäre Aufgabe besteht darin, Eingabegeräte zu verwalten und der Grafikkarte Anweisungen zur Pixelzeichnung zu übermitteln. Ein kritischer Punkt in der Initialisierungssequenz von Xorg ist die Erkennung einer sogenannten "Senke" (Sink) – eines physischen Geräts, das die generierten Bilddaten entgegennimmt.

Wenn der NVIDIA-Treiber der 470er-Serie gestartet wird, führt er einen Handshake über den Display Data Channel (DDC) durch. Erhält der Treiber keine Rückmeldung in Form einer EDID-Struktur, meldet er dem X-Server, dass keine nutzbaren Bildschirme vorhanden sind. Dies führt unweigerlich zu der Fehlermeldung (EE) no screens found, woraufhin der X-Server den Dienst quittiert. Ohne einen aktiven X-Server kann die GNOME-Shell nicht geladen werden, was wiederum die Initialisierung von Hardware-Encodern wie NVENC verhindert, die für das latenzfreie Streaming via Sunshine essentiell sind.   

# Ursachenanalyse von I/O-Port-Fehlern

Häufig tritt im Zusammenhang mit kopflosen Konfigurationen der Fehler xf86EnableIO: failed to enable I/O ports auf. Dies deutet darauf hin, dass der X-Server versucht, auf Hardware-Ressourcen zuzugreifen, die sich in einem Energiesparmodus befinden oder deren Zugriffsberechtigungen durch das Fehlen einer aktiven Sitzung (Session) eingeschränkt sind. In einer Standard-Desktop-Installation wird dieser Zugriff durch systemd-logind verwaltet. In einer kopflosen Umgebung fehlt jedoch oft der physische Auslöser für eine solche Sitzungserstellung.

Fehlercode,Bedeutung,Technische Ursache
(EE) no screens found,Xorg bricht ab,Der NVIDIA-Treiber meldet keine verbundenen Displays via DDC.
xf86EnableIO: failed,I/O-Zugriffsfehler,Fehlende Berechtigungen oder Hardware im D3-Cold-State.
(EE) No devices detected,GPU nicht gefunden,Treiberkonflikt (z. B. Nouveau) oder fehlerhafte Bus-ID.
Fatal server error,Kernabsturz des Servers,Kaskadierender Fehler nach fehlgeschlagener Screen-Initialisierung.

Die Analyse der Diagnoseprotokolle zeigt, dass das System zwar die Hardware korrekt via lspci identifiziert und die Kernel-Module lädt, aber an der logischen Grenze zwischen Kernel-Space und User-Space scheitert, da der Treiber die GPU ohne Monitor-Präsenz nicht vollständig in den Operationsmodus versetzt.   

# Technischer Deep-Dive: Die Rolle von EDID

EDID (Extended Display Identification Data) ist ein standardisiertes Datenformat, mit dem ein Monitor seine Fähigkeiten (Auflösungen, Bildwiederholraten, Farbräume) an die Grafikkarte übermittelt. In einem Binär-Blob von 128 oder 256 Bytes sind alle Informationen gespeichert, die der Treiber benötigt, um den Framebuffer korrekt zu dimensionieren.   

In einer kopflosen Konfiguration muss diese Kommunikation softwareseitig simuliert werden. Das Ziel ist es, dem Treiber vorzugaukeln, dass ein Monitor mit einer spezifischen Identität (z. B. 1080p bei 60Hz) permanent angeschlossen ist. Dies wird durch die Option CustomEDID in der Xorg-Konfiguration erreicht.   

# Struktur eines EDID-Datensatzes

Ein standardisierter EDID-Datensatz (Version 1.3/1.4) setzt sich aus verschiedenen Blöcken zusammen. Für die Emulation ist insbesondere der Header und der Block der "Preferred Timing Mode" von Bedeutung.

Byte-Offset,Länge,Beschreibung,Beispielwert (Hex)
00-07,8,Fixer Header,00 FF FF FF FF FF FF 00
08-09,2,Hersteller-ID,1E 6D
12-13,2,EDID-Version,01 03
36-53,18,Deskriptor für 1080p,02 3A 80 18 71 38 2D 40...
127,1,Prüfsumme,Variabel

Die Verwendung einer solchen Datei zwingt den Treiber, die Hardware-Ressourcen für diesen virtuellen Monitor zu reservieren, was die Bereitstellung von NVENC-Kapazitäten überhaupt erst ermöglicht.   

## Implementierungsstrategien unter NixOS

NixOS unterscheidet sich von imperativen Distributionen wie Ubuntu oder Arch Linux durch seine deklarative Natur. Konfigurationsänderungen werden nicht durch das manuelle Editieren von Dateien in /etc/X11/ vorgenommen, sondern über die zentrale Datei configuration.nix gesteuert. Dies erfordert ein Verständnis dafür, wie NixOS die Xorg-Konfigurationsdatei generiert.

# Erzwungene Konfiguration des NVIDIA-Treibers

Um den NVIDIA-Treiber der Version 470 zu zwingen, auch ohne Monitor zu starten, müssen spezifische Optionen in den Grafik-Stack injiziert werden. Die Option AllowEmptyInitialConfiguration ist hierbei der wichtigste Schalter. Sie wurde von NVIDIA eingeführt, um genau die Szenarien zu unterstützen, in denen der X-Server vor der physischen Verbindung eines Displays starten muss.

In Kombination mit ConnectedMonitor kann ein spezifischer Ausgang (z. B. DFP-0 für DisplayPort oder HDMI-0) als "belegt" markiert werden. Die technische Relevanz dieser Einstellung liegt darin, dass der Treiber den internen Zustandsautomaten für diesen Ausgang auf "verbunden" setzt, unabhängig von der tatsächlichen elektrischen Last am Port.

# Die Einbindung virtueller EDID-Dateien in NixOS

Ein Problem bei der Nutzung von CustomEDID unter NixOS ist die Referenzierung der Binärdatei. Da der Nix-Store unveränderlich ist, sollte die EDID-Datei entweder direkt als Pfad im Repository oder als generierte Datei eingebunden werden.

Die Analyse der verfügbaren Mechanismen zeigt zwei gangbare Wege:

Physische Datei: Die Datei edid.bin wird im Verzeichnis /etc/nixos/ abgelegt und in der Konfiguration absolut referenziert.

Nix-Derivation: Die EDID wird als Base64-String direkt in der Nix-Konfiguration gespeichert und beim Build-Vorgang in eine Binärdatei umgewandelt.   

Der zweite Weg ist aus Sicht der Reproduzierbarkeit vorzuziehen, da er alle Abhängigkeiten innerhalb der Konfiguration kapselt.

## Systemd-Integration und die Bedeutung von Linger

Ein oft übersehener Aspekt bei der Einrichtung von Sunshine auf NixOS ist das Prozessmanagement durch systemd. Sunshine wird üblicherweise als User-Service ausgeführt. Standardmäßig beendet systemd alle User-Prozesse, sobald sich der Benutzer abmeldet oder wenn keine aktive Sitzung erkannt wird.

Die Einstellung users.users.<name>.linger = true; weist systemd an, einen User-Manager für den spezifizierten Benutzer bereits beim Booten zu starten und diesen auch nach dem Abmelden aktiv zu lassen. Dies ist für Sunshine kritisch, da der Dienst im Hintergrund laufen muss, während der X-Server (der durch GNOME/GDM gestartet wird) versucht, sich zu initialisieren. Ohne Linger würde Sunshine niemals den Zustand erreichen, in dem es den Framebuffer abgreifen kann, da der Dienst erst gar nicht gestartet wird, solange die grafische Oberfläche im Fehlerzustand verharrt.   

# Interaktion zwischen GDM und Xorg

NixOS nutzt standardmäßig GDM als Display-Manager. GDM hat die Eigenschaft, bei Fehlern des X-Servers oder des Wayland-Compositors in eine Endlosschleife von Neustartversuchen zu verfallen. In den vorliegenden Diagnosedaten wurde Wayland deaktiviert (services.xserver.displayManager.gdm.wayland = false;), was für den 470er-Treiber korrekt ist, da dessen Wayland-Unterstützung mangelhaft ist.   

Allerdings führt dies dazu, dass GDM zwingend einen funktionierenden X-Server erwartet. Wenn dieser aufgrund der fehlenden EDID abstürzt, bleibt das System am blinkenden Cursor hängen. Die Lösung liegt darin, die Xorg-Konfiguration so robust zu gestalten, dass sie "blind" startet.

## Erweiterte Konfigurationsoptionen für Stabilität und Leistung

Neben der reinen Bildausgabe sind für ein flüssiges Streaming-Erlebnis weitere Parameter von Bedeutung. Diese betreffen vor allem das Powermanagement und die Persistenz des Treibers.

# HardDPMS und Power Management

Die Option HardDPMS steuert, wie der Treiber mit dem Display Power Management Signaling verfährt. In kopflosen Umgebungen sollte diese Option auf False gesetzt werden, um zu verhindern, dass der Treiber den virtuellen Ausgang abschaltet, weil er glaubt, der (nicht vorhandene) Monitor sei im Energiesparmodus.   

# Persistence Mode

Normalerweise entlädt der NVIDIA-Treiber Teile seines Zustands, wenn keine Anwendung aktiv auf die GPU zugreift. Dies kann beim Starten eines Streams zu Verzögerungen oder Fehlern führen. Durch das Aktivieren des "Persistence Mode" via nvidia-smi -pm 1 bleibt der Treiber permanent geladen und die GPU in einem betriebsbereiten Zustand. Unter NixOS kann dies über ein systemd.services-Unit realisiert werden, das nach dem Laden der NVIDIA-Module ausgeführt wird.   

Option,Wert,Zweck
AllowEmptyInitialConfiguration,True,Erlaubt X-Start ohne physischen Monitor.
ConnectedMonitor,DFP-0,Erzwingt die logische Präsenz eines Monitors an einem Port.
HardDPMS,False,Deaktiviert hardwareseitiges Abschalten des Ports.
Persistence Mode,Enabled,Hält den Treiber und die GPU-Ressourcen aktiv.

## Vergleich: Software-Emulation vs. Hardware-Dummy-Plug

Trotz der fortgeschrittenen Möglichkeiten der Software-Konfiguration bleibt der Einsatz eines physischen HDMI- oder DisplayPort-Dummy-Plugs eine attraktive Alternative.

Die softwareseitige Lösung bietet zwar maximale Flexibilität bei der Wahl der Auflösung und verursacht keine zusätzlichen Hardwarekosten, sie ist jedoch anfällig für Kernel-Updates oder Änderungen in der NVIDIA-Treiberstruktur. Insbesondere der Legacy-Treiber 470 gilt als launisch im Umgang mit virtuellen Konfigurationen auf Consumer-Karten.   

Ein Hardware-Dummy hingegen schließt den Stromkreis auf der untersten Ebene. Für die GPU ist die Präsenz eines Monitors eine physikalische Tatsache, keine softwareseitige Behauptung. Dies eliminiert einen Großteil der oben beschriebenen Fehlerbilder bereits in der Initialisierungsphase des Kernels (KMS). Dennoch ist die Software-Lösung für Administratoren, die keinen physischen Zugriff auf das System haben (z. B. in entfernten Rechenzentren oder virtualisierten Umgebungen), der einzige gangbare Weg.   

## Praktische Umsetzung der virtuellen EDID in NixOS

Um eine virtuelle EDID ohne externe Abhängigkeiten zu erzeugen, kann eine Nix-Expression genutzt werden, die den Hex-String direkt in eine Binärdatei im Nix-Store schreibt. Dies stellt sicher, dass die Datei bei jedem Systemaufbau vorhanden ist und nicht manuell nach /etc/nixos/ kopiert werden muss.

# Definition der BusID

Ein häufiger Fehler in virtualisierten Umgebungen (GPU-Passthrough) ist eine falsche Adressierung der Grafikkarte. Xorg versucht oft, das Gerät auf dem Standard-Slot zu finden. Wenn die Karte jedoch auf einem anderen PCI-Pfad liegt, schlägt die Initialisierung fehl. Die explizite Angabe der BusID in der Device-Sektion ist daher zwingend erforderlich. Diese muss dem Format PCI:X:Y:Z entsprechen, wobei die Werte aus der Ausgabe von lspci zu entnehmen sind.   

## Zusammenfassung der technischen Implikationen

Der Betrieb einer GTX 760 im kopflosen Modus unter NixOS erfordert eine präzise Abstimmung zwischen dem NVIDIA-Kernel-Modul, dem X-Server und der systemd-Sitzungsverwaltung. Die Analyse zeigt, dass der X-Server-Absturz (no screens found) das primäre Hindernis für alle nachgelagerten Dienste wie GNOME und Sunshine darstellt.   

Durch die deklarative Injektion einer EDID-Struktur und die Deaktivierung der hardwareabhängigen Sicherheitsprüfungen des Treibers kann die GPU in einen stabilen Betriebszustand versetzt werden. Dies ermöglicht die Nutzung der NVENC-Hardwarebeschleunigung, die für das Remote-Gaming-Szenario unverzichtbar ist. Die Aktivierung von linger stellt zudem sicher, dass die für Sunshine notwendigen User-Dienste unabhängig von einer physischen Benutzerinteraktion starten können.   

Abschließend lässt sich festhalten, dass die softwareseitige Lösung zwar eine hohe Komplexität aufweist, aber innerhalb des NixOS-Frameworks eine saubere und reproduzierbare Methode darstellt, um die künstlichen Beschränkungen der Consumer-Grafikhardware zu umgehen. Sollten jedoch trotz korrekter Konfiguration weiterhin Stabilitätsprobleme auftreten, bleibt der Hardware-Dummy-Plug die ultimative Lösung, um die GPU-Initialisierung auf elektrischer Ebene zu garantieren.


