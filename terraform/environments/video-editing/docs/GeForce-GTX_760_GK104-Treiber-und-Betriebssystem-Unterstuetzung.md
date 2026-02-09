## GeForce GTX 760 (GK104, Kepler) – Treiber & Betriebssystem-Unterstützung

### Proprietärer NVIDIA-Treiber (470.xx Legacy)

NVIDIA hat den aktiven Support für Kepler-GPUs am **31. August 2021** eingestellt. Der letzte unterstützte Treiberzweig ist **R470** (z.B. `470.256.02`).

| Aspekt | Status |
|---|---|
| **Neue Features / Game-Ready Updates** | Keine mehr |
| **Sicherheitsupdates** | Eingestellt seit September 2024 |
| **Vulkan-Support** | Maximal Vulkan 1.2 (kein Pfad zu 1.3) |

#### Linux-Kernel-Kompatibilität (kritisch für Passthrough!)

Der 470er-Treiber hat massive Kompatibilitätsprobleme mit neueren Kernels:

- **Kernel ≤ 6.8.x** – funktioniert (DKMS baut sauber)
- **Kernel 6.11+** – [Build-Fehler beim Kompilieren](https://forums.developer.nvidia.com/t/nvidia-driver-470-256-02-fails-to-compile-on-ubuntu-24-04-kernel-6-11-0-29/339777)
- **Kernel 6.12+** – [ebenfalls kaputt](https://forums.developer.nvidia.com/t/legacy-driver-470-256-02-fails-to-build-on-kernel-6-12/318277)
- **Kernel 6.14+** – nicht mehr kompilierbar

Das bedeutet: Auf deinem Fedora 43 mit **Kernel 6.18** wird der proprietäre 470er-Treiber **nicht funktionieren** – weder auf dem Host noch im Gast.

### Nouveau (Open-Source-Treiber)

| Aspekt | Status |
|---|---|
| **Kernel-Kompatibilität** | Funktioniert mit allen aktuellen Kernels |
| **Reclocking** | Manuell möglich ([nouveau-reclocking](https://github.com/ventureoo/nouveau-reclocking)), ohne Reclocking läuft die GPU auf Boot-Takt (sehr langsam) |
| **Vulkan (NVK)** | Ab **Mesa 25.2** – Kepler mit Vulkan 1.2 konform |
| **Performance** | ~80% des proprietären Treibers (mit Reclocking) |

### Unterstützte Betriebssysteme – Übersicht

| Betriebssystem | Treiber | Status |
|---|---|---|
| **Windows 10/11** | 473.xx (letzter Legacy-Zweig) | Funktioniert, aber keine neuen Features |
| **Windows 7/8/8.1** | 473.xx | Support ebenfalls eingestellt |
| **Linux (Kernel ≤ 6.8)** | nvidia-470 proprietär | Funktioniert |
| **Linux (Kernel 6.11+)** | nvidia-470 proprietär | Baut nicht mehr |
| **Linux (alle Kernels)** | Nouveau + NVK (Mesa ≥ 25.2) | Funktioniert, eingeschränkte Leistung |
| **FreeBSD** | nvidia-470 Legacy | Letzte unterstützte Version |

### Empfehlung für dein GPU-Passthrough-Setup

Für die GTX 760 als Passthrough-GPU in einer VM gibt es zwei realistische Szenarien:

1. **Windows 10/11 als Gast-VM** – Beste Option. Der Windows-Legacy-Treiber (473.xx) funktioniert problemlos im Gast, unabhängig vom Host-Kernel. Der Host nutzt VFIO, nicht den NVIDIA-Treiber.

2. **Linux als Gast-VM** – Schwieriger. Du bräuchtest entweder eine Distribution mit Kernel ≤ 6.8 im Gast, oder du nutzt Nouveau/NVK mit Mesa ≥ 25.2.

Da bei Passthrough der **Host** nur VFIO braucht (keinen NVIDIA-Treiber), ist dein Fedora 43 mit Kernel 6.18 als Host kein Problem. Der Treiber muss nur **im Gast** funktionieren.

---

### Quellen

- [Tom's Hardware – Nvidia Ends Support for Kepler](https://www.tomshardware.com/news/nvidia-end-support-kepler-gpu-windows7-windows-8-august-31)
- [Phoronix – NVIDIA 470 EOL vs Nouveau](https://www.phoronix.com/review/nouveau-kepler-2021)
- [NVIDIA Developer Forums – 470.256.02 fails on Kernel 6.11](https://forums.developer.nvidia.com/t/nvidia-driver-470-256-02-fails-to-compile-on-ubuntu-24-04-kernel-6-11-0-29/339777)
- [NVIDIA Developer Forums – 470 fails on Kernel 6.12](https://forums.developer.nvidia.com/t/legacy-driver-470-256-02-fails-to-build-on-kernel-6-12/318277)
- [Collabora – Mesa 25.2 NVK Kepler Support](https://www.collabora.com/news-and-blog/news-and-events/mesa-25.2-brings-new-hardware-support-for-nouveau-users.html)
- [iTechWonders – Kepler Linux Gaming 2026](https://itechwonders.com/nvidia-gt-750m-kepler-linux-gaming-2026/)
- [nouveau-reclocking auf GitHub](https://github.com/ventureoo/nouveau-reclocking)
