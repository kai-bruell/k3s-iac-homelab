# Butane & Ignition Deep Dive

## Was ist Ignition?

**Ignition** ist ein Provisionierungs-System, das speziell für Flatcar Container Linux (und Fedora CoreOS) entwickelt wurde. Es läuft **einmalig** beim ersten Boot und konfiguriert das System **atomar** und **deterministisch**.

## Warum Ignition und nicht cloud-init?

### cloud-init vs Ignition

| Feature | cloud-init | Ignition |
|---------|-----------|----------|
| **Wann läuft es?** | Nach dem Boot (Userspace) | In initramfs (vor root mount) |
| **Atomarität** | Nein (kann halb-fehlschlagen) | Ja (alles oder nichts) |
| **Filesystem-Änderungen** | Schwierig/Gefährlich | Native Unterstützung |
| **Partition erstellen** | Kompliziert | Einfach |
| **Fehler-Handling** | Weiter mit Boot | Stop und Fehler anzeigen |
| **Idempotenz** | Muss selbst implementiert werden | Garantiert |
| **Komplexität** | Scripts, Imperative Befehle | Deklarative Konfiguration |

### Ignition Vorteile

1. **Läuft in initramfs**
   - Vor dem Mounten des Root-Filesystems
   - Kann Partitionen sicher erstellen/ändern
   - Kein laufendes System, das im Weg ist

2. **Atomar**
   - Entweder komplett erfolgreich oder VM bootet nicht
   - Keine "halb-konfigurierten" Systeme in Produktion
   - Einfaches Debugging: Funktioniert oder nicht

3. **Deterministisch**
   - Gleiche Config = Gleicher Zustand
   - Keine Abhängigkeit von externen Faktoren
   - Reproduzierbar über Jahre hinweg

4. **Immutable**
   - Config wird nur beim ersten Boot angewendet
   - Keine nachträglichen Änderungen möglich
   - Zwingt zu Infrastructure as Code Patterns

## Was ist Butane?

**Butane** ist ein Tool, das human-readable YAML in Ignition JSON kompiliert.

### Warum Butane?

Ignition verwendet JSON, das für Computer perfekt, aber für Menschen unlesbar ist:

**Ignition JSON (Auszug):**
```json
{
  "ignition": {
    "version": "3.3.0"
  },
  "storage": {
    "files": [{
      "path": "/etc/hostname",
      "mode": 420,
      "contents": {
        "source": "data:,k3s-server-1"
      }
    }]
  }
}
```

**Butane YAML (gleichwertig):**
```yaml
variant: flatcar
version: 1.1.0

storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: k3s-server-1
```

Butane ist **viel lesbarer** und wird automatisch zu Ignition kompiliert.

## Butane Config Struktur

### Grundstruktur

```yaml
variant: flatcar          # OS-Typ (flatcar oder fcos)
version: 1.1.0           # Butane Config Version

passwd:                  # Benutzer & SSH Keys
  users: []

storage:                 # Filesystem-Konfiguration
  directories: []        # Verzeichnisse erstellen
  files: []              # Dateien schreiben
  links: []              # Symlinks erstellen

systemd:                 # Systemd Services
  units: []              # Services definieren
```

### passwd Section

Benutzer und SSH-Keys konfigurieren:

```yaml
passwd:
  users:
    - name: core                    # Standard-User in Flatcar
      ssh_authorized_keys:          # SSH Public Keys
        - ssh-ed25519 AAAAC3Nz... user@host
        - ssh-rsa AAAAB3NzaC1... another@host
```

**Wichtig:**
- Flatcar hat standardmäßig nur den User `core`
- Kein Root-Login möglich
- Nur SSH Key Authentication (kein Password)

### storage Section

#### Verzeichnisse erstellen

```yaml
storage:
  directories:
    - path: /opt/bin
      mode: 0755              # Permissions (octal)
      user:
        name: core            # Optional: Owner
      group:
        name: core            # Optional: Group
```

#### Dateien schreiben

**Einfache Datei:**
```yaml
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: k3s-server-1
```

**Executable Script:**
```yaml
storage:
  files:
    - path: /opt/install-k3s.sh
      mode: 0755              # Executable
      contents:
        inline: |             # Multi-line mit |
          #!/bin/bash
          set -euo pipefail

          echo "Installing k3s..."
          curl -sfL https://get.k3s.io | sh -
```

**Datei von URL:**
```yaml
storage:
  files:
    - path: /opt/myapp
      mode: 0755
      contents:
        source: https://example.com/myapp  # Download von URL
        verification:
          hash: sha512-abc123...            # Optional: Hash-Verification
```

**Templating mit Terraform:**

Unsere Configs nutzen Terraform's `templatefile()`:

```yaml
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${hostname}    # ← Wird von Terraform ersetzt!
```

Terraform ersetzt `${hostname}` mit dem tatsächlichen Wert:

```hcl
data "ct_config" "vm_config" {
  content = templatefile("config.yaml", {
    hostname       = "k3s-dev-server-1"
    ssh_keys       = jsonencode(["ssh-ed25519 AAAA..."])
    k3s_token      = "secret-token"
    k3s_server_url = ""
  })
}
```

### systemd Section

Systemd Units erstellen und aktivieren:

**Oneshot Service (einmalig ausführen):**
```yaml
systemd:
  units:
    - name: install-k3s.service
      enabled: true           # Automatisch starten
      contents: |
        [Unit]
        Description=Install k3s
        After=network-online.target        # Nach Netzwerk
        Wants=network-online.target
        ConditionPathExists=!/usr/local/bin/k3s  # Nur wenn k3s nicht existiert

        [Service]
        Type=oneshot                       # Einmalig ausführen
        RemainAfterExit=yes                # Als "active" markieren nach Erfolg
        ExecStart=/opt/install-k3s.sh
        StandardOutput=journal             # Logs in journalctl
        StandardError=journal

        [Install]
        WantedBy=multi-user.target
```

**Service modifizieren (Dropin):**
```yaml
systemd:
  units:
    - name: update-engine.service
      enabled: true           # Service aktivieren
      dropins:
        - name: 40-custom.conf
          contents: |
            [Service]
            Environment="UPDATE_SERVER=https://my-server.com"
```

**Wichtige Service-Typen:**
- `Type=oneshot` - Einmalig ausführen, dann beenden
- `Type=simple` - Langläufiger Prozess (Standard)
- `Type=forking` - Daemon der forkt

**Wichtige Unit-Direktiven:**
- `After=` - Startet nach dieser Unit
- `Requires=` - Braucht diese Unit (hartes Requirement)
- `Wants=` - Möchte diese Unit (weiches Requirement)
- `ConditionPathExists=` - Nur starten wenn Pfad existiert
- `ConditionPathExists=!` - Nur starten wenn Pfad NICHT existiert

## Unser k3s-server Butane Config erklärt

Lass uns die Config Zeile für Zeile durchgehen:

### 1. Header & User

```yaml
variant: flatcar
version: 1.1.0

passwd:
  users:
    - name: core
      ssh_authorized_keys: ${ssh_keys}  # Von Terraform injiziert
```

- `variant: flatcar` - Wir nutzen Flatcar Linux
- `version: 1.1.0` - Butane Config Version (nicht OS-Version!)
- SSH Keys werden von Terraform als JSON-Array übergeben

### 2. Verzeichnisse

```yaml
storage:
  directories:
    - path: /opt/bin
      mode: 0755
    - path: /etc/rancher/k3s
      mode: 0755
    - path: /var/lib/rancher/k3s/server/manifests
      mode: 0755
```

- `/opt/bin` - Für eigene Binaries/Scripts
- `/etc/rancher/k3s` - k3s Konfiguration
- `/var/lib/rancher/k3s/server/manifests` - Auto-Deploy Manifests (k3s Feature)

**k3s Feature:** Alle YAML-Dateien in `/var/lib/rancher/k3s/server/manifests/` werden automatisch deployed!

### 3. Installation Script

```yaml
storage:
  files:
    - path: /opt/install-k3s.sh
      mode: 0755
      contents:
        inline: |
          #!/bin/bash
          set -euo pipefail

          # Download k3s installer
          curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
          chmod +x /tmp/k3s-install.sh

          # Install k3s server
          %{if k3s_server_url != ""}
          # Additional server node (HA setup)
          K3S_TOKEN="${k3s_token}" \
          K3S_URL="${k3s_server_url}" \
          INSTALL_K3S_EXEC="server \
            --disable traefik \
            --disable servicelb \
            --write-kubeconfig-mode=644 \
            --node-label node-type=server \
            --flannel-backend=host-gw" \
          /tmp/k3s-install.sh
          %{else}
          # First server node
          K3S_TOKEN="${k3s_token}" \
          INSTALL_K3S_EXEC="server \
            --cluster-init \
            --disable traefik \
            --disable servicelb \
            --write-kubeconfig-mode=644 \
            --node-label node-type=server \
            --flannel-backend=host-gw" \
          /tmp/k3s-install.sh
          %{endif}

          # Wait for k3s to be ready
          until kubectl get nodes; do
            echo "Waiting for k3s to be ready..."
            sleep 5
          done

          echo "k3s server installed successfully!"
```

**Script-Analyse:**

1. `set -euo pipefail` - Bash Best Practice
   - `-e` - Stop bei Fehler
   - `-u` - Stop bei undefined Variable
   - `-o pipefail` - Fehler in Pipes erkennen

2. `%{if k3s_server_url != ""}` - Terraform Conditional
   - Wenn `k3s_server_url` leer → Erster Server
   - Wenn gesetzt → Zusätzlicher Server (HA)

3. **k3s Flags:**
   - `--cluster-init` - Embedded etcd starten (nur erster Server!)
   - `--disable traefik` - Traefik Ingress Controller deaktivieren
   - `--disable servicelb` - ServiceLB deaktivieren (nutzen MetalLB später)
   - `--write-kubeconfig-mode=644` - Kubeconfig lesbar machen
   - `--node-label node-type=server` - Label für Node-Selektor
   - `--flannel-backend=host-gw` - Schnelleres Netzwerk (Layer 2)

4. Wartet bis kubectl funktioniert (k3s installiert kubectl automatisch)

### 4. Hostname setzen

```yaml
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${hostname}
```

Terraform ersetzt `${hostname}` mit z.B. `k3s-dev-server-1`.

### 5. Systemd Services

#### install-k3s Service

```yaml
systemd:
  units:
    - name: install-k3s.service
      enabled: true
      contents: |
        [Unit]
        Description=Install k3s
        After=network-online.target
        Wants=network-online.target
        ConditionPathExists=!/usr/local/bin/k3s

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/opt/install-k3s.sh
        StandardOutput=journal
        StandardError=journal

        [Install]
        WantedBy=multi-user.target
```

- `After=network-online.target` - Wartet auf Netzwerk
- `ConditionPathExists=!/usr/local/bin/k3s` - Nur starten wenn k3s NICHT existiert
- `Type=oneshot` - Einmal ausführen
- `RemainAfterExit=yes` - Als "active" markieren nach Erfolg

**Wichtig:** k3s wird nur beim ersten Boot installiert! Bei Reboots läuft der k3s Service selbst.

#### Flatcar Update Services

```yaml
    - name: locksmithd.service
      enabled: true
      dropins:
        - name: 40-strategy.conf
          contents: |
            [Service]
            Environment="REBOOT_STRATEGY=reboot"

    - name: update-engine.service
      enabled: true
```

**Flatcar Auto-Update System:**
- `update-engine.service` - Lädt Updates herunter
- `locksmithd.service` - Koordiniert Reboots im Cluster
- `REBOOT_STRATEGY=reboot` - Automatisch rebooten nach Update

**Wie es funktioniert:**
1. update-engine lädt neue Flatcar Version
2. Update wird in zweite Partition installiert
3. locksmithd koordiniert mit anderen Nodes
4. Node rebooted in neue Version
5. Bei Problemen: Rollback zur alten Partition

#### Timezone Service

```yaml
    - name: set-timezone.service
      enabled: true
      contents: |
        [Unit]
        Description=Set timezone
        After=network-online.target

        [Service]
        Type=oneshot
        ExecStart=/usr/bin/timedatectl set-timezone Europe/Berlin
        RemainAfterExit=yes

        [Install]
        WantedBy=multi-user.target
```

Setzt Timezone auf Europe/Berlin.

### 6. Extra Config

```yaml
${extra_config}
```

Ermöglicht zusätzliche Butane-Config von Terraform. Nutzen wir aktuell nicht, aber nützlich für:
- Zusätzliche Manifests deployen
- Custom systemd services
- Monitoring agents

## k3s-agent Config Unterschiede

Der Agent ist simpler, da er nur zum Server connecten muss:

**Hauptunterschied im Script:**

```yaml
# Wait for server to be available
echo "Waiting for k3s server at ${k3s_server_url}..."
until curl -k -s "${k3s_server_url}/ping" > /dev/null 2>&1; do
  echo "Server not ready yet, waiting..."
  sleep 5
done

# Install k3s agent
K3S_TOKEN="${k3s_token}" \
K3S_URL="${k3s_server_url}" \
INSTALL_K3S_EXEC="agent \
  --node-label node-type=agent" \
/tmp/k3s-install.sh
```

- Wartet bis Server erreichbar ist (`/ping` endpoint)
- Installiert mit `agent` statt `server`
- Braucht `K3S_URL` (Server URL)
- Viel weniger Flags

**Kein manifest-Verzeichnis:**
```yaml
directories:
  - path: /opt/bin
    mode: 0755
  - path: /etc/rancher/k3s
    mode: 0755
  # KEIN /var/lib/rancher/k3s/server/manifests - nur Server hat das!
```

## Terraform Integration

### ct Provider

```hcl
terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13"
    }
  }
}
```

Der **Poseidon ct Provider** kompiliert Butane zu Ignition.

### Butane → Ignition Kompilierung

```hcl
data "ct_config" "vm_config" {
  content = templatefile(var.butane_config_path, {
    hostname       = var.vm_name
    ssh_keys       = jsonencode(var.ssh_keys)
    k3s_role       = var.k3s_role
    k3s_token      = var.k3s_token
    k3s_server_url = var.k3s_server_url
    extra_config   = var.extra_butane_config
  })
  strict = true
}
```

**Was passiert:**
1. `templatefile()` liest Butane YAML
2. Ersetzt alle `${variable}` Platzhalter
3. `ct_config` Data Source kompiliert zu Ignition JSON
4. `strict = true` - Fehler bei ungültiger Config

### Ignition an libvirt übergeben

```hcl
resource "libvirt_ignition" "ignition" {
  name    = "${var.vm_name}-ignition"
  content = data.ct_config.vm_config.rendered  # ← Kompiliertes JSON
  pool    = libvirt_pool.vm_pool.name
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  vcpu   = var.vcpu
  memory = var.memory

  coreos_ignition = libvirt_ignition.ignition.id  # ← Ignition Config!

  disk {
    volume_id = libvirt_volume.vm.id
  }
}
```

**libvirt macht:**
1. Erstellt ISO-Image mit Ignition JSON
2. Hängt ISO an VM als CD-ROM
3. Flatcar findet Ignition beim Boot
4. Ignition konfiguriert System

## Best Practices

### 1. Idempotenz sicherstellen

**Gut:**
```yaml
systemd:
  units:
    - name: install-k3s.service
      contents: |
        [Unit]
        ConditionPathExists=!/usr/local/bin/k3s  # ← Nur wenn nicht existiert!
```

**Schlecht:**
```yaml
# Würde bei jedem Boot versuchen zu installieren
```

### 2. Fehler-Handling

**Gut:**
```bash
#!/bin/bash
set -euo pipefail  # ← Stop bei Fehler!

curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
/tmp/k3s-install.sh
```

**Schlecht:**
```bash
#!/bin/bash
# Läuft weiter auch bei Fehlern
curl https://get.k3s.io | sh
```

### 3. Logs in journalctl

```yaml
[Service]
StandardOutput=journal  # ← Logs in journalctl!
StandardError=journal
```

Dann debuggen mit:
```bash
ssh core@192.168.122.10
journalctl -u install-k3s.service -f
```

### 4. Dependencies richtig setzen

**Gut:**
```yaml
[Unit]
After=network-online.target
Wants=network-online.target
```

**Schlecht:**
```yaml
[Unit]
# Startet zu früh, Netzwerk eventuell nicht bereit
```

### 5. Secrets sicher handhaben

**Gut:**
```hcl
variable "k3s_token" {
  type      = string
  sensitive = true  # ← Wird nicht in Logs gezeigt!
}
```

**Schlecht:**
```yaml
# Token direkt in Butane-Config hardcoded
```

## Debugging

### Ignition Logs ansehen

```bash
ssh core@<vm-ip>
journalctl -u ignition-firstboot.service
```

### Butane Config validieren (lokal)

```bash
# Butane installieren
docker run --rm -i quay.io/coreos/butane:latest \
  --pretty --strict < config.yaml > ignition.json
```

### Terraform Plan ansehen

```bash
terraform plan
# Zeigt kompiliertes Ignition (gekürzt)
```

## Zusammenfassung

**Butane + Ignition Flow:**

```
1. Schreibe Butane YAML (human-readable)
   ↓
2. Terraform templatefile() ersetzt Variablen
   ↓
3. Poseidon ct Provider kompiliert zu Ignition JSON
   ↓
4. libvirt_ignition erstellt ISO-Image
   ↓
5. VM bootet mit Ignition Config
   ↓
6. Flatcar liest Ignition aus ISO
   ↓
7. Ignition konfiguriert System (atomar!)
   ↓
8. Systemd Services starten
   ↓
9. k3s wird installiert
   ↓
10. System ist betriebsbereit
```

**Key Takeaways:**

- Ignition läuft VOR dem Boot (initramfs)
- Atomar: Alles oder nichts
- Deterministisch: Gleiche Config = Gleicher Zustand
- Immutable: Nur beim ersten Boot
- Butane = Human-readable YAML
- Ignition = Machine-optimized JSON
- Terraform automatisiert die Kompilierung
