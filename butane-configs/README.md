# Butane Configurations

Diese Butane-Konfigurationen definieren die **initiale Provisionierung** der Flatcar Linux VMs für den k3s Kubernetes Cluster. Sie werden von Terraform in Ignition JSON kompiliert und beim **ersten Boot** der VMs angewendet.

## Was ist Butane?

**Butane** ist ein Tool, das menschenlesbare YAML-Konfigurationen in **Ignition JSON** übersetzt. Ignition ist das native Provisionierungssystem von Flatcar Container Linux und konfiguriert das System **einmalig** beim ersten Boot - **atomar** und **immutable**.

## Verfügbare Konfigurationen

### k3s-server/config.yaml

Konfiguration für **k3s Control Plane Nodes** (Server).

**Was wird konfiguriert:**
- SSH-Zugriff für `core` User mit autorisierten Keys
- Verzeichnisstruktur: `/opt/bin`, `/etc/rancher/k3s`, `/var/lib/rancher/k3s/server/manifests`
- k3s Server Installation Script
- Hostname
- Systemd Services:
  - `install-k3s.service` - Installiert k3s im Server-Modus
  - `locksmithd.service` - Koordiniert automatische Flatcar Updates
  - `update-engine.service` - Lädt Flatcar Updates herunter
  - `set-timezone.service` - Setzt Timezone auf Europe/Berlin

**k3s Server Features:**
- **Erster Server:** Nutzt `--cluster-init` für embedded etcd (HA-fähig)
- **Weitere Server:** Joinen zum ersten Server (für HA-Setup)
- Traefik Ingress Controller deaktiviert (`--disable traefik`)
- ServiceLB deaktiviert (`--disable servicelb`)
- Flannel Host-Gateway Backend für schnelleres Netzwerk
- Kubeconfig mit Leserechten (`--write-kubeconfig-mode=644`)
- Node-Label: `node-type=server`

**Manifest Auto-Deploy:**
Der Ordner `/var/lib/rancher/k3s/server/manifests` ist besonders - alle YAML-Dateien dort werden automatisch von k3s deployed!

### k3s-agent/config.yaml

Konfiguration für **k3s Worker Nodes** (Agents).

**Was wird konfiguriert:**
- SSH-Zugriff für `core` User mit autorisierten Keys
- Verzeichnisstruktur: `/opt/bin`, `/etc/rancher/k3s`
- k3s Agent Installation Script
- Hostname
- Systemd Services:
  - `install-k3s.service` - Installiert k3s im Agent-Modus mit Retry-Logik
  - `locksmithd.service` - Koordiniert automatische Flatcar Updates
  - `update-engine.service` - Lädt Flatcar Updates herunter
  - `set-timezone.service` - Setzt Timezone auf Europe/Berlin

**k3s Agent Features:**
- Wartet automatisch bis k3s Server erreichbar ist (`/ping` endpoint)
- Joint zum angegebenen k3s Server (`K3S_URL`)
- Node-Label: `node-type=agent`
- Restart bei Fehler (z.B. wenn Server noch nicht bereit)

## Terraform Template-Variablen

Die Butane-Configs nutzen Terraform's `templatefile()` Funktion. Folgende Variablen werden zur Laufzeit ersetzt:

| Variable | Beschreibung | Beispiel |
|----------|--------------|----------|
| `${hostname}` | VM Hostname | `k3s-dev-server-1` |
| `${ssh_keys}` | SSH Public Keys (JSON Array) | `["ssh-ed25519 AAAA..."]` |
| `${k3s_token}` | k3s Cluster Token (Secret) | `abc123...` |
| `${k3s_server_url}` | k3s API Server URL | `https://192.168.122.10:6443` |
| `${extra_config}` | Zusätzliche Butane-Config | Optional |

**Conditional Logic:**
- Server: `%{if k3s_server_url != ""}` prüft ob erster Server oder zusätzlicher HA-Server

## Ignition Flow

```
1. Terraform liest Butane YAML
   ↓
2. templatefile() ersetzt ${variablen}
   ↓
3. Poseidon ct Provider kompiliert zu Ignition JSON
   ↓
4. libvirt erstellt ISO-Image mit Ignition Config
   ↓
5. VM bootet mit ISO als CD-ROM
   ↓
6. Flatcar liest Ignition in initramfs (VOR root mount!)
   ↓
7. Ignition konfiguriert System atomar:
   - Erstellt Benutzer & SSH Keys
   - Erstellt Verzeichnisse & Dateien
   - Aktiviert Systemd Services
   ↓
8. System bootet vollständig
   ↓
9. install-k3s.service startet automatisch
   ↓
10. k3s wird installiert und gestartet
   ↓
11. Cluster ist betriebsbereit
```

## Wichtige Konzepte

### Immutable Infrastructure

Diese Configs werden **nur beim ersten Boot** angewendet. Änderungen an der Config erfordern:
1. Config in Git ändern
2. `terraform apply` ausführen
3. Terraform erstellt **neue** VM mit neuer Config
4. Alte VM wird gelöscht

**Keine manuellen Änderungen** auf den VMs! Das ist der Kern von Immutable Infrastructure.

### Idempotenz

Die Services nutzen `ConditionPathExists=!/usr/local/bin/k3s` - k3s wird nur installiert wenn es noch nicht existiert. Bei Reboots läuft k3s als normaler systemd Service.

### Fehlerbehandlung

- Bash Scripts nutzen `set -euo pipefail` (Stop bei Fehler)
- Agents haben `Restart=on-failure` und warten auf Server-Verfügbarkeit
- Alle Logs gehen nach journalctl (abrufbar via SSH)

## Debugging

### Ignition Logs

```bash
ssh core@<vm-ip>
sudo journalctl -u ignition-firstboot.service
```

### Installation Logs

```bash
# Server
ssh core@<server-ip>
sudo journalctl -u install-k3s.service

# Agent
ssh core@<agent-ip>
sudo journalctl -u install-k3s.service -f
```

### k3s Logs

```bash
# Server
sudo journalctl -u k3s -f

# Agent
sudo journalctl -u k3s-agent -f
```

## Anpassungen

### Eigene Manifests deployen

Füge in `k3s-server/config.yaml` unter `storage.files` hinzu:

```yaml
- path: /var/lib/rancher/k3s/server/manifests/my-app.yaml
  mode: 0644
  contents:
    inline: |
      apiVersion: v1
      kind: Namespace
      metadata:
        name: my-app
```

k3s deployed dies automatisch beim Start!

### Timezone ändern

In beiden Configs unter `set-timezone.service`:

```yaml
ExecStart=/usr/bin/timedatectl set-timezone America/New_York
```

### Flatcar Update-Strategie ändern

Standard ist `REBOOT_STRATEGY=reboot` (automatischer Reboot nach Update).

Alternativen:
- `off` - Keine automatischen Updates
- `etcd-lock` - Koordiniert mit etcd (für größere Cluster)
- `best-effort` - Update nur wenn sicher

## Weiterführende Dokumentation

- **[../docs/01-butane-ignition.md](../docs/01-butane-ignition.md)** - Detaillierte Erklärung von Butane & Ignition
- **[../docs/02-terraform-modules.md](../docs/02-terraform-modules.md)** - Wie Terraform die Configs nutzt
- **[Butane Config Specification](https://coreos.github.io/butane/config-flatcar-v1_1/)** - Offizielle Butane Docs
- **[Ignition Specification](https://coreos.github.io/ignition/)** - Low-Level Ignition Details

## Zusammenfassung

Diese Butane-Configs sind das **Herzstück** der automatisierten VM-Provisionierung:

- **Deklarativ** - Du beschreibst den Ziel-Zustand
- **Atomar** - Alles oder nichts, keine halb-konfigurierten Systeme
- **Immutable** - Nur beim ersten Boot, keine nachträglichen Änderungen
- **Reproduzierbar** - Gleiche Config = Gleicher Zustand
- **Versioniert** - In Git, vollständige Historie

Sie ermöglichen **Infrastructure as Code** und **Immutable Infrastructure** - moderne, professionelle Infrastruktur-Praktiken!
