# Homelab IaC Documentation

Infrastructure as Code für automatisiertes Kubernetes Cluster Deployment auf Flatcar Linux VMs.

Automatisiertes Deployment eines **k3s Kubernetes Clusters** auf **Flatcar Container Linux** mit **OpenTofu**, **libvirt/KVM** und **GitOps (FluxCD)**.

## Dokumentation

### Einstieg

- **[00-overview.md](00-overview.md)** - Architektur, Technologie-Stack, Konzepte
- **[01-butane-ignition.md](01-butane-ignition.md)** - VM-Provisionierung mit Butane/Ignition
- **[02-terraform-modules.md](02-terraform-modules.md)** - Terraform Module und Flow

## Quick Reference

### Wichtige Befehle

**OpenTofu:**
```bash
cd terraform/environments/development
tofu init       # Provider installieren
tofu plan       # Änderungen anzeigen
tofu apply      # Ausführen
tofu destroy    # Alles löschen
tofu output     # Outputs anzeigen
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
homelab/
├── butane-configs/          # VM-Provisionierung (Ignition)
│   ├── k3s-server/         # Control Plane
│   └── k3s-agent/          # Worker Nodes
│
├── terraform/              # Infrastructure as Code
│   ├── modules/
│   │   ├── flatcar-vm/    # VM-Modul
│   │   └── k3s-cluster/   # Cluster-Orchestrierung
│   └── environments/
│       ├── development/
│       ├── staging/
│       └── production/
│
├── kubernetes/             # GitOps Manifests (FluxCD)
│   ├── flux-system/       # FluxCD Bootstrap
│   ├── clusters/          # Environment-spezifisch
│   ├── infrastructure/    # Base Services (Traefik, etc.)
│   └── apps/             # Applikationen
│
└── docs/                  # Dokumentation

## Technologie-Stack

| Komponente | Version | Zweck |
|------------|---------|-------|
| **Flatcar Linux** | Stable | Immutable Container OS |
| **k3s** | Latest | Lightweight Kubernetes |
| **OpenTofu** | >= 1.0 | Infrastructure as Code |
| **libvirt** | ~> 0.7 | KVM Virtualisierung |
| **Butane/Ignition** | ~> 0.13 / 3.3.0 | VM Provisionierung |

## Konzepte

### Immutable Infrastructure

**Mutable (traditionell):**
```
VM erstellen → SSH → Pakete installieren → Config editieren → Hoffen
```

**Immutable (moderner Ansatz):**
```
Config in Git → tofu apply → VM startet fertig konfiguriert
```

VMs werden beim ersten Boot via Ignition konfiguriert und dann nicht mehr verändert. Änderungen erfordern Neudeployment.

### Cattle vs. Pets

Ein gängiger Begriff im DevOps-Bereich:

- **Pets**: Manuell konfigurierte Server mit Namen. Bei Ausfall aufwendige Wiederherstellung.
- **Cattle**: Identische, austauschbare Instanzen aus Code provisioniert. Bei Problemen: Wegwerfen und neu erstellen.

Diese Infrastruktur behandelt VMs als Cattle - jederzeit aus Code reproduzierbar.

### Infrastructure as Code

Gesamte Infrastruktur versioniert in Git:
- Butane Configs für VM-Provisionierung
- Terraform Modules für Infrastruktur
- Kubernetes Manifests für Services

Ein Befehl für Deployment, ein Befehl zum Löschen.

### Declarative Configuration

**Imperativ (Befehle):**
```bash
curl https://get.k3s.io | sh
systemctl start k3s
```

**Deklarativ (Zustandsbeschreibung):**
```yaml
systemd:
  units:
    - name: k3s.service
      enabled: true
```

Ignition und Terraform setzen den gewünschten Zustand um.

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

### Production-Einsatz möglich?

Die verwendeten Prinzipien sind production-ready:
- Immutable Infrastructure ✓
- Infrastructure as Code ✓
- Declarative Configuration ✓
- Automated Provisioning ✓

Für Production-Deployments zusätzlich empfohlen:
- Bare-metal oder Cloud-Provider statt lokaler libvirt VMs
- HA Control Plane (3+ Server Nodes)
- Backup-Strategie (etcd Snapshots)
- Monitoring & Alerting
- GitOps für App-Deployments

## Ressourcen

### Offizielle Dokumentation

- [Flatcar Linux](https://www.flatcar.org/docs/latest/)
- [Butane Configs](https://coreos.github.io/butane/)
- [Ignition Specification](https://coreos.github.io/ignition/)
- [k3s Documentation](https://docs.k3s.io/)
- [OpenTofu Docs](https://opentofu.org/docs/)
- [libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [FluxCD Documentation](https://fluxcd.io/docs/)

### Verwandte Projekte

- [Talos Linux](https://www.talos.dev/) - API-driven Kubernetes OS
- [k0s](https://k0sproject.io/) - Zero-friction Kubernetes
- [RKE2](https://docs.rke2.io/) - Rancher Kubernetes Distribution
- [OpenTofu](https://opentofu.org/) - Open-Source Terraform Fork

