# Homelab IaC Documentation

Willkommen zur Dokumentation für das Homelab Infrastructure as Code Projekt!

Dieses Projekt zeigt, wie man einen **k3s Kubernetes Cluster** auf **Flatcar Container Linux** mit **Terraform** und **libvirt** deployed - vollständig automatisiert und nach **Immutable Infrastructure** Prinzipien.

## Dokumentations-Index

### Für Einsteiger

Start hier wenn du neu bist:

**[00-overview.md](00-overview.md)** - Projekt-Übersicht
- Was ist dieses Projekt?
- Technologie-Stack Erklärung
- Architektur-Überblick
- Warum Immutable Infrastructure?
- Provisionierungs-Flow
- Key Concepts

**[03-getting-started.md](03-getting-started.md)** - Praktischer Setup-Guide
- Voraussetzungen & Installation
- Schritt-für-Schritt Deployment
- Cluster-Zugriff einrichten
- Troubleshooting
- Nächste Schritte

### Für Deep Dive

Wenn du jedes Detail verstehen willst:

**[01-butane-ignition.md](01-butane-ignition.md)** - Butane & Ignition Deep Dive
- Was ist Ignition und warum nicht cloud-init?
- Butane Config Struktur
- Alle Config-Sections erklärt
- k3s-server vs k3s-agent Configs
- Terraform Integration
- Best Practices
- Debugging

**[02-terraform-modules.md](02-terraform-modules.md)** - Terraform Module Architektur
- Modul-Hierarchie
- flatcar-vm Modul (VM-Erstellung)
- k3s-cluster Modul (Orchestrierung)
- development Environment
- Terraform Flow Visualisiert
- Dependency Graphs
- Best Practices

## Empfohlener Lernpfad

### Level 1: Verstehen

1. **[00-overview.md](00-overview.md)** lesen
   - Verstehe die Architektur
   - Lerne die Technologien kennen
   - Verstehe warum Immutable Infrastructure

2. **[01-butane-ignition.md](01-butane-ignition.md)** lesen
   - Verstehe Ignition vs cloud-init
   - Lerne Butane Config Syntax
   - Verstehe wie VMs konfiguriert werden

3. **[02-terraform-modules.md](02-terraform-modules.md)** lesen
   - Verstehe Modul-Struktur
   - Lerne Terraform Patterns
   - Verstehe den kompletten Flow

### Level 2: Anwenden

4. **[03-getting-started.md](03-getting-started.md)** durcharbeiten
   - Installiere Dependencies
   - Deploye deinen ersten Cluster
   - Teste kubectl Zugriff
   - Deploye eine Test-App

### Level 3: Experimentieren

5. Eigene Änderungen
   - Ändere Butane Configs
   - Passe Terraform Variablen an
   - Füge mehr Nodes hinzu
   - Deploye eigene Apps

### Level 4: Erweitern

6. Erweiterte Features
   - Installiere Ingress Controller
   - Konfiguriere Load Balancer (MetalLB)
   - Setup Monitoring (Prometheus/Grafana)
   - Implementiere GitOps (Flux/ArgoCD)

## Quick Reference

### Wichtige Befehle

**Terraform:**
```bash
cd terraform/environments/development
terraform init       # Provider installieren
terraform plan       # Änderungen anzeigen
terraform apply      # Ausführen
terraform destroy    # Alles löschen
terraform output     # Outputs anzeigen
```

**libvirt:**
```bash
virsh list --all               # VMs anzeigen
virsh console k3s-dev-server-1 # Console öffnen (Ctrl+] beenden)
virsh net-list                 # Netzwerke anzeigen
virsh pool-list                # Storage Pools anzeigen
```

**kubectl:**
```bash
export KUBECONFIG=~/.kube/k3s-dev-config
kubectl get nodes              # Nodes anzeigen
kubectl get pods -A            # Alle Pods
kubectl get svc -A             # Alle Services
```

**SSH:**
```bash
ssh core@192.168.122.10  # Server
ssh core@192.168.122.11  # Agent 1
ssh core@192.168.122.12  # Agent 2
```

### Wichtige Dateien

**Terraform:**
- `terraform/environments/development/terraform.tfvars` - Deine Konfiguration
- `terraform/modules/flatcar-vm/main.tf` - VM-Erstellung
- `terraform/modules/k3s-cluster/main.tf` - Cluster-Orchestrierung

**Butane:**
- `butane-configs/k3s-server/config.yaml` - Server-Config
- `butane-configs/k3s-agent/config.yaml` - Agent-Config

**Logs (auf VMs):**
```bash
# Ignition
sudo journalctl -u ignition-firstboot.service

# k3s Installation
sudo journalctl -u install-k3s.service

# k3s Server
sudo journalctl -u k3s -f

# k3s Agent
sudo journalctl -u k3s-agent -f
```

## Projekt-Struktur

```
homelab-iac/
├── butane-configs/
│   ├── k3s-server/config.yaml    # Control Plane Config
│   └── k3s-agent/config.yaml     # Worker Config
│
├── terraform/
│   ├── modules/
│   │   ├── flatcar-vm/           # VM-Modul
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── k3s-cluster/          # Cluster-Modul
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── environments/
│       └── development/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars.example
│
└── docs/                         # Diese Dokumentation
    ├── README.md                 # Dieser Index
    ├── 00-overview.md
    ├── 01-butane-ignition.md
    ├── 02-terraform-modules.md
    └── 03-getting-started.md
```

## Technologie-Stack

| Komponente | Version | Zweck |
|------------|---------|-------|
| **Flatcar Linux** | Stable | Immutable Container OS |
| **k3s** | Latest | Lightweight Kubernetes |
| **Terraform** | >= 1.0 | Infrastructure as Code |
| **libvirt** | ~> 0.7 | KVM Virtualisierung |
| **Butane/Ignition** | ~> 0.13 / 3.3.0 | VM Provisionierung |

## Konzepte

### Immutable Infrastructure

**Traditional (Mutable):**
```
VM erstellen → SSH → Pakete installieren → Config editieren → Hoffen
```

**Immutable (unser Ansatz):**
```
Config in Git → Terraform apply → VM startet konfiguriert → Fertig
```

**Vorteile:**
- Deterministisch
- Reproduzierbar
- Versioniert
- Keine Config Drift

### Infrastructure as Code

Komplette Infrastruktur in Git:
- Butane Configs
- Terraform Modules
- Environment Variables

**Ein Befehl erstellt alles:**
```bash
terraform apply
```

**Ein Befehl löscht alles:**
```bash
terraform destroy
```

### Declarative Configuration

**Imperativ (wie):**
```bash
curl https://get.k3s.io | sh
systemctl start k3s
```

**Deklarativ (was):**
```yaml
systemd:
  units:
    - name: k3s.service
      enabled: true
```

Ignition & Terraform kümmern sich ums "Wie"!

## FAQs

### Warum Flatcar statt Ubuntu?

- **Immutable:** Read-only `/usr`, Updates via A/B Partitionen
- **Container-optimiert:** Minimale Installation, nur das Nötigste
- **Auto-Updates:** Automatische Sicherheitsupdates mit Rollback
- **Ignition:** Native Provisionierung, kein cloud-init Overhead

### Warum k3s statt k8s?

- **Lightweight:** < 512 MB RAM statt 2+ GB
- **Single Binary:** Einfache Installation
- **Edge-optimiert:** Perfekt für Homelab/Edge
- **Voll kompatibel:** Normales Kubernetes, nur kleiner

### Warum libvirt statt Docker/Podman?

- **Echte VMs:** Isolation auf Kernel-Level
- **Näher an Production:** Cloud-Provider nutzen auch VMs
- **Immutable OS:** Flatcar funktioniert am besten als VM
- **Lerneffekt:** Verstehe wie Cloud-VMs funktionieren

### Kann ich das in Production nutzen?

**Ja, aber:**
- Nutze bare-metal statt libvirt VMs (oder Cloud-Provider)
- Implementiere HA für Control Plane (3+ Server Nodes)
- Setup Backup-Strategie (etcd Snapshots)
- Monitoring & Alerting (Prometheus/Grafana)
- GitOps für App-Deployments (Flux/ArgoCD)

**Prinzipien sind Production-Ready:**
- Immutable Infrastructure ✓
- Infrastructure as Code ✓
- Declarative Configuration ✓
- Automated Provisioning ✓

## Weiterführende Ressourcen

### Offizielle Dokumentation

- [Flatcar Linux Docs](https://www.flatcar.org/docs/latest/)
- [Butane Configs](https://coreos.github.io/butane/)
- [Ignition Specification](https://coreos.github.io/ignition/)
- [k3s Documentation](https://docs.k3s.io/)
- [Terraform Docs](https://www.terraform.io/docs)
- [libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)

### Verwandte Projekte

- [Talos Linux](https://www.talos.dev/) - Alternative zu Flatcar (API-driven)
- [k0s](https://k0sproject.io/) - Alternative zu k3s
- [RKE2](https://docs.rke2.io/) - Rancher's k8s Distribution
- [OpenTofu](https://opentofu.org/) - Open-Source Terraform Fork

## Unterstützung

### Bei Problemen

1. Prüfe **[03-getting-started.md](03-getting-started.md)** Troubleshooting Section
2. Schaue in die Logs (siehe Quick Reference oben)
3. Prüfe Terraform State: `terraform state list`
4. Öffne ein GitHub Issue mit:
   - Terraform Version
   - Error Messages
   - Relevante Logs

### Beitragen

Pull Requests willkommen für:
- Dokumentations-Verbesserungen
- Bugfixes
- Neue Features
- Zusätzliche Beispiele

## Lizenz

Dieses Projekt steht unter der MIT Lizenz.

## Zusammenfassung

Du hast jetzt Zugriff auf:

- ✅ **Komplette Dokumentation** des Projekts
- ✅ **Lernpfad** vom Einsteiger zum Expert
- ✅ **Praktische Guides** für Deployment
- ✅ **Deep Dives** in Technologien
- ✅ **Best Practices** für Production

**Viel Erfolg beim Lernen und Experimentieren!**

Start mit **[00-overview.md](00-overview.md)** oder springe direkt zu **[03-getting-started.md](03-getting-started.md)** wenn du loslegen willst!
