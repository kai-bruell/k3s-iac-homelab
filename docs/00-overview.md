# Homelab Infrastructure as Code - Übersicht

## Was ist dieses Projekt?

Dieses Projekt ermöglicht die automatisierte Provisionierung eines k3s Kubernetes-Clusters auf Flatcar Linux VMs mit libvirt/KVM. Es demonstriert **Immutable Infrastructure** Prinzipien und enterprise-grade Deployment-Praktiken.

## Technologie-Stack

### Core-Technologien

1. **Flatcar Container Linux**
   - Immutable Linux Distribution
   - Speziell für Container-Workloads optimiert
   - Automatische Updates mit Rollback-Fähigkeit
   - Konfiguration nur via Ignition beim ersten Boot

2. **Butane & Ignition**
   - **Butane**: Human-readable YAML Config-Format
   - **Ignition**: JSON-basiertes Provisionierungs-System
   - Butane wird zu Ignition kompiliert
   - Ignition konfiguriert das System beim ersten Boot **einmalig und atomar**

3. **Terraform**
   - Infrastructure as Code
   - Deklarative Beschreibung der Infrastruktur
   - Idempotent und reproduzierbar

4. **libvirt/KVM**
   - Open-Source Virtualisierung
   - KVM: Kernel-based Virtual Machine
   - libvirt: API und Tooling für VM-Management

5. **k3s**
   - Lightweight Kubernetes Distribution
   - Reduzierter Footprint (< 512MB RAM)
   - Single-Binary Installation
   - Perfekt für Edge/Homelab

## Architektur-Überblick

```
┌─────────────────────────────────────────────────────────────┐
│                    Host System (Arch Linux)                 │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   libvirt/KVM                        │   │
│  │                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │   │
│  │  │   k3s-dev    │  │   k3s-dev    │  │  k3s-dev    │ │   │
│  │  │   -server-1  │  │   -agent-1   │  │  -agent-2   │ │   │
│  │  │              │  │              │  │             │ │   │
│  │  │ Flatcar Linux│  │ Flatcar Linux│  │Flatcar Linux│ │   │
│  │  │  + k3s       │  │  + k3s       │  │ + k3s       │ │   │
│  │  │  (control    │  │  (worker)    │  │ (worker)    │ │   │
│  │  │   plane)     │  │              │  │             │ │   │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │   │
│  │                                                      │   │
│  │  Ignition Config applied at first boot               │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  Terraform manages VM lifecycle                             │
└─────────────────────────────────────────────────────────────┘
```

## Projekt-Struktur

```
homelab-iac/
├── butane-configs/          # Butane Configuration Templates
│   ├── k3s-server/          # Control Plane Nodes
│   │   └── config.yaml
│   └── k3s-agent/           # Worker Nodes
│       └── config.yaml
│
├── terraform/
│   ├── modules/             # Wiederverwendbare Module
│   │   ├── flatcar-vm/      # Basis VM-Modul
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── k3s-cluster/     # k3s Cluster-Modul
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── environments/        # Environment-spezifische Configs
│       └── development/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars.example
│
└── docs/                    # Diese Dokumentation
```

## Warum Immutable Infrastructure?

### Das Problem mit traditionellen VMs

**Traditional (Mutable) Approach:**
```
VM erstellen → SSH einloggen → Pakete installieren →
Config-Files editieren → Services starten → Hoffen dass es funktioniert
```

**Probleme:**
- **Config Drift**: Manuelle Änderungen führen zu nicht-reproduzierbaren Zuständen
- **Snowflake Servers**: Jeder Server ist einzigartig, schwer zu replizieren
- **Debugging-Albtraum**: "Works on my machine"
- **Sicherheitsrisiko**: Nachträgliche Änderungen können übersehen werden

### Die Immutable Infrastructure Lösung

**Immutable Approach (mit Ignition):**
```
Config definieren → VM erstellen → Ignition wendet Config an →
System ist fertig konfiguriert → Keine weiteren Änderungen möglich
```

**Vorteile:**
- **Deterministisch**: Gleiche Config = Gleicher Zustand
- **Reproduzierbar**: Einfach neue identische VMs erstellen
- **Atomar**: Entweder komplett erfolgreich oder gar nicht
- **Sicher**: Keine unautorisierten Änderungen möglich
- **Versionskontrolle**: Komplette Infrastruktur in Git

## Provisionierungs-Flow

### High-Level Flow

```
1. Butane Config (YAML)
   ↓
2. Terraform templatefile() ersetzt Variablen
   ↓
3. Poseidon ct Provider kompiliert zu Ignition (JSON)
   ↓
4. Terraform erstellt libvirt_ignition Resource (ISO-Image)
   ↓
5. Terraform erstellt VM mit coreos_ignition Attribut
   ↓
6. VM bootet → Flatcar liest Ignition Config
   ↓
7. Ignition konfiguriert System:
   - Erstellt Benutzer & SSH Keys
   - Erstellt Verzeichnisse & Dateien
   - Aktiviert Systemd Services
   ↓
8. install-k3s.service startet automatisch
   ↓
9. k3s wird installiert und gestartet
   ↓
10. Cluster ist betriebsbereit
```

### Detaillierter Terraform Flow

```hcl
# 1. Butane Template mit Variablen
data "ct_config" "vm_config" {
  content = templatefile("config.yaml", {
    hostname       = "k3s-dev-server-1"
    ssh_keys       = ["ssh-ed25519 AAAA..."]
    k3s_token      = "secret-token"
    k3s_server_url = ""  # Leer für ersten Server
  })
}

# 2. Ignition Resource erstellen
resource "libvirt_ignition" "ignition" {
  name    = "k3s-dev-server-1-ignition"
  content = data.ct_config.vm_config.rendered  # Kompiliertes Ignition JSON
  pool    = "k3s-dev-pool"
}

# 3. VM mit Ignition Config erstellen
resource "libvirt_domain" "vm" {
  name   = "k3s-dev-server-1"
  vcpu   = 2
  memory = 4096

  coreos_ignition = libvirt_ignition.ignition.id  # ← Hier wird Ignition übergeben!

  disk {
    volume_id = libvirt_volume.vm.id
  }
}
```

## Was passiert beim ersten Boot?

### Flatcar Boot-Prozess

1. **VM startet** mit Flatcar Linux Base Image
2. **Ignition wird aktiviert** (vor allen anderen Services)
3. **Ignition liest Config** vom libvirt_ignition ISO-Image
4. **Ignition führt aus:**
   ```
   - Erstellt /home/core/.ssh/authorized_keys
   - Erstellt /opt/bin/, /etc/rancher/k3s/
   - Schreibt /opt/install-k3s.sh
   - Schreibt /etc/hostname
   - Aktiviert systemd Units
   ```
5. **Systemd startet Services:**
   ```
   - install-k3s.service → Installiert k3s
   - update-engine.service → Automatische Updates
   - locksmithd.service → Koordiniert Reboots
   ```

### k3s Installation (Server)

```bash
# /opt/install-k3s.sh wird ausgeführt

# 1. Installer herunterladen
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh

# 2. k3s installieren (erster Server)
K3S_TOKEN="secret-token" \
INSTALL_K3S_EXEC="server \
  --cluster-init \              # Embedded etcd
  --disable traefik \           # Traefik Ingress deaktivieren
  --disable servicelb \         # ServiceLB deaktivieren
  --write-kubeconfig-mode=644 \ # Kubeconfig lesbar machen
  --node-label node-type=server \
  --flannel-backend=host-gw" \  # Flannel Netzwerk-Backend
/tmp/k3s-install.sh

# 3. Warten bis k3s bereit ist
until kubectl get nodes; do
  sleep 5
done
```

### k3s Installation (Agent)

```bash
# 1. Warten bis Server erreichbar ist
until curl -k -s "https://192.168.122.10:6443/ping"; do
  sleep 5
done

# 2. k3s Agent installieren
K3S_TOKEN="secret-token" \
K3S_URL="https://192.168.122.10:6443" \
INSTALL_K3S_EXEC="agent \
  --node-label node-type=agent" \
/tmp/k3s-install.sh
```

## Warum kein SSH/Ansible/cloud-init?

| Methode | Wann es läuft | Idempotenz | Atomarität |
|---------|---------------|------------|------------|
| SSH/Ansible | Nach dem Boot | Schwer zu garantieren | Nein |
| cloud-init | Nach dem Boot | Teilweise | Nein |
| **Ignition** | **VOR dem Boot** | **Garantiert** | **Ja** |

**Ignition Vorteile:**
- Läuft in initramfs (vor root filesystem mount)
- Atomar: Entweder komplett erfolgreich oder VM bootet nicht
- Keine "halb-konfigurierten" Systeme
- Deterministisch: Gleiche Config = Gleicher Zustand
- Sicher: Config kann nicht nachträglich verändert werden

## Key Concepts

### 1. Storage Pool

```hcl
resource "libvirt_pool" "vm_pool" {
  name = "k3s-dev-pool"
  type = "dir"
  path = "/var/lib/libvirt/images"
}
```

Logischer Container für VM-Disks. Ähnlich wie Docker Volumes.

### 2. Base Image & Copy-on-Write

```hcl
# Basis-Image (wird nie verändert)
resource "libvirt_volume" "base" {
  name   = "k3s-dev-base.img"
  source = "/home/user/Downloads/flatcar_production_qemu_image.img"
  pool   = libvirt_pool.vm_pool.name
}

# VM-spezifisches Volume (CoW)
resource "libvirt_volume" "vm" {
  name           = "k3s-dev-server-1.qcow2"
  base_volume_id = libvirt_volume.base.id  # ← Copy-on-Write!
  pool           = libvirt_pool.vm_pool.name
}
```

**Copy-on-Write (CoW):**
- Basis-Image bleibt unverändert
- Jede VM schreibt nur ihre Änderungen (Delta)
- Spart massiv Speicherplatz
- Schnellere VM-Erstellung

### 3. Terraform Module

**Module = Wiederverwendbare Terraform-Komponenten**

```
flatcar-vm Modul        → Erstellt eine einzelne VM
   ↓
k3s-cluster Modul       → Nutzt flatcar-vm mehrfach für Server + Agents
   ↓
development Environment → Nutzt k3s-cluster mit spezifischer Config
```

**Vorteile:**
- DRY (Don't Repeat Yourself)
- Separation of Concerns
- Einfache Wiederverwendung
- Zentrale Updates

## Nächste Schritte

Lies die detaillierten Dokumentationen:

1. **01-butane-ignition.md** - Tiefes Verständnis von Butane/Ignition
2. **02-terraform-modules.md** - Wie die Terraform Module funktionieren
3. **03-getting-started.md** - Praktischer Setup-Guide

## Zusammenfassung

Dieses Projekt zeigt, wie moderne Infrastructure as Code aussieht:

- **Deklarativ**: Du beschreibst den Ziel-Zustand, nicht die Schritte
- **Immutable**: Keine manuellen Änderungen, nur neue Deployments
- **Reproduzierbar**: Gleicher Code = Gleiche Infrastruktur
- **Versioniert**: Komplette Historie in Git
- **Enterprise-Grade**: Patterns aus produktiven Kubernetes-Clustern

Es ist **kein** "Quick & Dirty" Setup mit SSH-Scripts, sondern eine **professionelle, wartbare Infrastruktur-Lösung**.
