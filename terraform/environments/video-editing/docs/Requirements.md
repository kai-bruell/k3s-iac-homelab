Hier ist die aktualisierte und finale Fassung der `Requirements.md`. Diese dokumentiert den aktuellen Status deines Systems, in dem bereits alle Voraussetzungen für das GPU-Passthrough erfolgreich erfüllt sind.

# Requirements: GTX 760 (GK104) GPU-Passthrough

## 1. Status der Host-Validierung (Erfüllt)

Die Vorbereitungen auf dem Proxmox-Host wurden erfolgreich abgeschlossen. Das System ist bereit, die GPU exklusiv an eine virtuelle Maschine zu übergeben.

### Durchgeführte Prüfungen & Ergebnisse:

* **Virtualisierung (IOMMU):** Aktiv. Der Kernel hat die IOMMU-Unterstützung für das Intel-System erfolgreich geladen (`DMAR: IOMMU enabled`).
* **IOMMU-Gruppierung:** Validiert. Die Hardware-Ressourcen sind in isolierten Gruppen organisiert, wobei sich die GPU in einer sauberen Gruppe (Gruppe 9) befindet.
* **GPU-Isolierung:** Erfolgreich. Die Grafikkarte (ID `10de:1187`) und der Audio-Controller (ID `10de:0e0a`) sind fest an den `vfio-pci` Treiber gebunden. Der Host-Betriebssystem greift nicht mehr auf die Hardware zu.

---

## 2. Die drei essentiellen Prüfbefehle

Mit diesen Befehlen wurde der Status "Alles erfüllt" verifiziert:

1. **IOMMU-Status prüfen:**
`dmesg | grep -e DMAR -e IOMMU`
*(Bestätigt die hardwareseitige Aktivierung im BIOS und Kernel)*.
2. **IOMMU-Gruppen auflisten:**
`find /sys/kernel/iommu_groups/ -type l`
*(Bestätigt, dass die Geräte für das Passthrough isoliert werden können)*.
3. **Treiber-Bindung verifizieren:**
`lspci -nnk | grep -A 3 "GTX 760"`
*(Bestätigt, dass `Kernel driver in use: vfio-pci` aktiv ist)*.

---

## 3. Anforderungen an das Gast-System (VM)

Da die Hardware-Ebene bereit ist, muss die zu installierende Linux-VM folgende Spezifikationen einhalten, um die Kepler-GPU stabil zu betreiben:

* **Empfohlener Kernel:** **Linux 6.6 LTS**. Dies ist zwingend erforderlich, da der NVIDIA-Legacy-Treiber (470.xx) bei neueren Kernel-Versionen (ab 6.11) Build-Fehler aufweist.
* **Treiber-Version:** **NVIDIA 470.256.02**. Dies ist der letzte unterstützte Zweig für die GK104-Architektur.
* **VM-Hardware-Profil:**
* **Machine:** `q35`.
* **BIOS:** `OVMF (UEFI)`.
* **PCI-Gerät:** Hinzufügen der Host-PCI-ID `81:00` mit den Optionen `All Functions` und `PCI-Express`.



---

**Gesamtstatus:** **READY** – Alle Anforderungen auf der Host-Seite sind zu 100 % erfüllt.
