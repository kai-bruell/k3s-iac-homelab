# Getting Started - k3s Cluster auf Flatcar Linux

Diese Anleitung führt dich Schritt für Schritt durch das Setup eines k3s Kubernetes Clusters mit Terraform und Flatcar Linux.

## Voraussetzungen

### System Requirements

- **OS:** Linux (Arch, Ubuntu, Fedora, etc.) mit KVM-Support
- **CPU:** x86_64 mit Virtualisierung (Intel VT-x oder AMD-V)
- **RAM:** Mindestens 8 GB (für 1 Server + 2 Agents)
- **Disk:** ~20 GB freier Speicherplatz

### Software Installation

#### 1. KVM/libvirt

**Arch Linux:**
```bash
sudo pacman -S qemu-full libvirt virt-manager dnsmasq ebtables iptables-nft
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt $USER
```

**Ubuntu/Debian:**
```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Fedora:**
```bash
sudo dnf install @virtualization
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Nach Installation:**
```bash
# Logout/Login für Gruppenmitgliedschaft
# Dann testen:
virsh list --all
# Sollte leer sein, aber KEIN Fehler
```

#### 2. Terraform

**Arch Linux:**
```bash
sudo pacman -S terraform
```

**Ubuntu/Debian:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Fedora:**
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install terraform
```

**Alternativ (alle Distros):**
```bash
# Binary Download
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

#### 3. Flatcar Linux Image herunterladen

```bash
cd ~/Downloads

# Stable Release (empfohlen)
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2

# Entpacken
bunzip2 flatcar_production_qemu_image.img.bz2

# Verifizieren
ls -lh flatcar_production_qemu_image.img
# Sollte ~1 GB sein
```

**Alternative Channels:**
- **Stable:** Produktionsreif, empfohlen
- **Beta:** Weniger getestet
- **Alpha:** Experimentell

Wir nutzen **Stable** für maximale Stabilität.

## Projekt Setup

### 1. Repository klonen

```bash
cd ~/
git clone <dein-repo-url> homelab-iac
cd homelab-iac
```

**Struktur prüfen:**
```bash
tree
# .
# ├── butane-configs/
# │   ├── k3s-agent/
# │   └── k3s-server/
# └── terraform/
#     ├── environments/
#     └── modules/
```

### 2. SSH Key generieren (falls nötig)

```bash
# Prüfen ob SSH Key existiert
ls ~/.ssh/id_ed25519.pub

# Falls nicht: Generieren
ssh-keygen -t ed25519 -C "your_email@example.com"

# Public Key anzeigen
cat ~/.ssh/id_ed25519.pub
```

### 3. Terraform Variablen konfigurieren

```bash
cd terraform/environments/development

# Beispiel-Datei kopieren
cp terraform.tfvars.example terraform.tfvars

# Editieren
vim terraform.tfvars  # oder nano, code, etc.
```

**terraform.tfvars anpassen:**

```hcl
# libvirt Connection
libvirt_uri = "qemu:///system"

# Cluster Name
cluster_name = "k3s-dev"

# Flatcar Base Image - ANPASSEN!
base_image_path = "/home/DEIN_USER/Downloads/flatcar_production_qemu_image.img"

# Storage Pool
pool_path = "/var/lib/libvirt/images"

# SSH Keys - DEIN KEY EINTRAGEN!
ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbcdef... user@hostname"
]

# Server Nodes (1 Control Plane)
server_count  = 1
server_vcpu   = 2
server_memory = 4096  # 4 GB RAM

# Agent Nodes (2 Workers)
agent_count  = 2
agent_vcpu   = 2
agent_memory = 2048   # 2 GB RAM pro Agent

# Network
network_name  = "default"
graphics_type = "spice"

# k3s Token (optional - wird automatisch generiert)
# k3s_token = "my-secret-token"
```

**Wichtig:**
- `base_image_path` mit deinem User-Pfad ersetzen
- `ssh_keys` mit deinem Public Key ersetzen

## Deployment

### 1. Terraform initialisieren

```bash
cd terraform/environments/development

terraform init
```

**Was passiert:**
- Provider werden heruntergeladen (libvirt, ct, random)
- Module werden geladen
- Backend wird initialisiert

**Output:**
```
Initializing modules...
- k3s_cluster in ../../modules/k3s-cluster
- k3s_cluster.k3s_agents in ../../modules/flatcar-vm
- k3s_cluster.k3s_servers in ../../modules/flatcar-vm

Initializing provider plugins...
- Finding dmacvicar/libvirt versions matching "~> 0.7"...
- Finding poseidon/ct versions matching "~> 0.13"...
- Finding hashicorp/random versions matching "~> 3.5"...
```

### 2. Terraform Plan

```bash
terraform plan
```

**Was passiert:**
- Terraform berechnet benötigte Änderungen
- Zeigt alle Ressourcen die erstellt werden
- Kompiliert Butane zu Ignition (du siehst das JSON)

**Prüfen:**
- Anzahl Ressourcen: ~15-20 (abhängig von node count)
- Keine Errors
- IP-Ranges passen (192.168.122.x)

**Expected Output:**
```
Plan: 17 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + agent_ips          = [
      + (known after apply),
      + (known after apply),
    ]
  + k3s_server_url     = (known after apply)
  + k3s_token          = (sensitive value)
  + kubeconfig_command = (known after apply)
  + server_ips         = [
      + (known after apply),
    ]
```

### 3. Terraform Apply

```bash
terraform apply
```

Terraform fragt nach Bestätigung:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Tippe `yes` und drücke Enter.

**Was passiert (Dauer: ~5-10 Minuten):**

1. **Storage Pool erstellen** (sofort)
2. **Base Image kopieren** (~30 Sekunden)
3. **Server VM erstellen** (~1 Minute)
   - Ignition kompilieren
   - VM Volume erstellen
   - VM starten
   - Auf IP warten
4. **k3s Server Installation** (~2-3 Minuten)
   - k3s Installer herunterladen
   - k3s installieren
   - k3s starten
5. **Agent VMs erstellen** (~2 Minuten)
   - Parallel zu Server (schneller)
6. **k3s Agents joinen** (~2 Minuten)
   - Warten bis Server erreichbar
   - k3s Agent installieren
   - Zum Cluster joinen

**Live-Monitoring:**

In einem anderen Terminal:
```bash
# libvirt VMs ansehen
watch -n 2 'virsh list --all'

# VM Console (optional)
virsh console k3s-dev-server-1
# Ctrl+] zum Beenden
```

### 4. Outputs prüfen

```bash
terraform output
```

**Expected Output:**
```
agent_ips = [
  "192.168.122.11",
  "192.168.122.12",
]
k3s_server_url = "https://192.168.122.10:6443"
k3s_token = <sensitive>
kubeconfig_command = "scp core@192.168.122.10:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev-config"
server_ips = [
  "192.168.122.10",
]
```

**Token anzeigen:**
```bash
terraform output -raw k3s_token
# abc123def456... (48 Zeichen)
```

## Cluster Zugriff

### 1. kubeconfig herunterladen

```bash
# Verzeichnis erstellen
mkdir -p ~/.kube

# kubeconfig kopieren (nutze den Output von terraform)
scp core@192.168.122.10:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev-config

# Server-IP anpassen (Standard ist 127.0.0.1)
sed -i 's/127.0.0.1/192.168.122.10/g' ~/.kube/k3s-dev-config
```

### 2. kubectl installieren (falls nicht vorhanden)

**Arch Linux:**
```bash
sudo pacman -S kubectl
```

**Ubuntu/Debian:**
```bash
sudo snap install kubectl --classic
# oder
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### 3. Cluster testen

```bash
# kubeconfig setzen
export KUBECONFIG=~/.kube/k3s-dev-config

# Nodes anzeigen
kubectl get nodes

# Expected Output:
# NAME                STATUS   ROLES                  AGE   VERSION
# k3s-dev-server-1    Ready    control-plane,master   5m    v1.28.x+k3s1
# k3s-dev-agent-1     Ready    <none>                 3m    v1.28.x+k3s1
# k3s-dev-agent-2     Ready    <none>                 3m    v1.28.x+k3s1

# Alle Pods anzeigen
kubectl get pods -A

# System-Komponenten prüfen
kubectl get pods -n kube-system
```

**Alle Nodes sollten "Ready" sein!**

### 4. Test-Deployment

```bash
# Nginx deployen
kubectl create deployment nginx --image=nginx

# Warten bis Running
kubectl get pods -w

# Service erstellen
kubectl expose deployment nginx --port=80 --type=NodePort

# Service anzeigen
kubectl get svc nginx

# Testen (NodePort ist random 30000-32767)
curl http://192.168.122.10:<NodePort>
# Sollte Nginx Welcome Page zeigen
```

## SSH-Zugriff auf Nodes

### Server

```bash
ssh core@192.168.122.10
```

**Nützliche Befehle:**
```bash
# k3s Status
sudo systemctl status k3s

# k3s Logs
sudo journalctl -u k3s -f

# Ignition Logs (erster Boot)
sudo journalctl -u ignition-firstboot.service

# Installation Script Logs
sudo journalctl -u install-k3s.service

# Nodes vom Server aus
sudo kubectl get nodes

# OS Version
cat /etc/os-release
# NAME="Flatcar Container Linux by Kinvolk"
```

### Agents

```bash
ssh core@192.168.122.11  # Agent 1
ssh core@192.168.122.12  # Agent 2
```

**Nützliche Befehle:**
```bash
# k3s-agent Status
sudo systemctl status k3s-agent

# k3s-agent Logs
sudo journalctl -u k3s-agent -f

# Pods auf diesem Node
sudo crictl pods
```

## Cluster Management

### Nodes hinzufügen

**In terraform.tfvars ändern:**
```hcl
agent_count = 3  # statt 2
```

**Applyen:**
```bash
terraform apply
```

Terraform erstellt nur den neuen Agent!

### Nodes entfernen

**In terraform.tfvars ändern:**
```hcl
agent_count = 1  # statt 2
```

**Applyen:**
```bash
terraform apply
```

**Wichtig:** Terraform löscht den **letzten** Agent (k3s-dev-agent-2)!

### Cluster löschen

```bash
terraform destroy
```

**Bestätigen:**
```
Do you really want to destroy all resources?
  Enter a value: yes
```

**Was passiert:**
- VMs werden gestoppt und gelöscht
- Volumes werden gelöscht
- Storage Pool wird gelöscht
- Ignition Configs werden gelöscht

**Flatcar Image bleibt:** Du musst es nicht erneut herunterladen!

### Cluster neu erstellen

```bash
terraform apply
```

Erstellt alles von Grund auf neu. **Gleicher Zustand** dank Ignition!

## Troubleshooting

### VM bootet nicht

**Prüfen:**
```bash
virsh list --all
# Sollte VMs zeigen

virsh console k3s-dev-server-1
# Ctrl+] zum Beenden
```

**Ignition Fehler:**
```bash
ssh core@192.168.122.10
sudo journalctl -u ignition-firstboot.service
```

### k3s installiert nicht

**Server Logs:**
```bash
ssh core@192.168.122.10
sudo journalctl -u install-k3s.service
```

**Häufige Probleme:**
- Netzwerk nicht verfügbar → Wartet auf network-online.target
- Download fehlgeschlagen → Proxy-Problem?
- Token falsch → Terraform apply erneut

### Agent joined nicht

**Agent Logs:**
```bash
ssh core@192.168.122.11
sudo journalctl -u install-k3s.service -f
```

**Prüfen:**
```bash
# Server erreichbar?
curl -k https://192.168.122.10:6443/ping
# Sollte 404 oder ähnlich sein (wichtig: Verbindung klappt!)

# Token korrekt?
# Auf Server:
ssh core@192.168.122.10 'sudo cat /var/lib/rancher/k3s/server/node-token'
# Sollte mit Terraform Token übereinstimmen
```

### Terraform apply hängt

**Häufig bei:**
- `wait_for_lease = true` - Wartet auf DHCP IP

**Prüfen:**
```bash
# libvirt Netzwerk aktiv?
virsh net-list --all

# Default Netzwerk starten
virsh net-start default
virsh net-autostart default

# DHCP läuft?
virsh net-dhcp-leases default
```

### IP-Adressen ändern sich

**Normal!** DHCP vergibt IPs dynamisch.

**Feste IPs (optional):**

In `terraform/modules/flatcar-vm/main.tf`:
```hcl
network_interface {
  network_name   = var.network_name
  addresses      = [var.fixed_ip]  # Feste IP
  wait_for_lease = false
}
```

Aber: Erfordert DHCP-Reservation oder Static Config.

**Einfacher:** Nutze DNS oder akzeptiere dynamische IPs.

### Terraform State kaputt

**Symptom:**
```
Error: resource already exists
```

**Fix:**
```bash
# State-File ansehen
terraform state list

# Einzelne Resource entfernen
terraform state rm module.k3s_cluster.module.k3s_servers[0].libvirt_domain.vm

# Oder komplett neu:
rm -rf .terraform terraform.tfstate*
terraform init
terraform apply
```

**Wichtig:** VMs bleiben in libvirt! Manuell löschen:
```bash
virsh destroy k3s-dev-server-1
virsh undefine k3s-dev-server-1 --remove-all-storage
```

## Best Practices

### 1. Git Ignore

**.gitignore:**
```
# Terraform
.terraform/
terraform.tfstate
terraform.tfstate.backup
.terraform.lock.hcl

# Secrets
terraform.tfvars
*.auto.tfvars

# SSH
*.pem
*.key
```

**terraform.tfvars.example committen**, aber NICHT terraform.tfvars!

### 2. Terraform Workspace (optional)

Mehrere Environments parallel:

```bash
# Development
terraform workspace new development
terraform workspace select development
terraform apply

# Production
terraform workspace new production
terraform workspace select production
terraform apply -var-file=production.tfvars
```

### 3. State Backend (optional)

Für Teams: Terraform State in S3/Remote Backend:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "k3s-dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 4. Snapshots

Vor Major Changes:

```bash
# VM Snapshot erstellen
virsh snapshot-create-as k3s-dev-server-1 before-update "Vor k3s Update"

# Snapshots anzeigen
virsh snapshot-list k3s-dev-server-1

# Snapshot wiederherstellen
virsh snapshot-revert k3s-dev-server-1 before-update

# Snapshot löschen
virsh snapshot-delete k3s-dev-server-1 before-update
```

**Aber:** Widerspricht Immutable Infrastructure! Besser: Neue VMs deployen.

### 5. Resource Limits

**Überwachen:**
```bash
# Host Resources
htop

# libvirt Pool
virsh pool-info k3s-dev-pool

# VM Resources
virsh dominfo k3s-dev-server-1
```

## Nächste Schritte

### 1. Persistent Storage

k3s nutzt standardmäßig **local-path** Storage:

```bash
kubectl get sc
# NAME                   PROVISIONER             RECLAIMPOLICY
# local-path (default)   rancher.io/local-path   Delete
```

**Für Production:** Nutze echtes Persistent Storage (NFS, Longhorn, Ceph).

### 2. Ingress Controller

Traefik ist deaktiviert. Installiere z.B. **nginx-ingress**:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
```

### 3. Load Balancer

ServiceLB ist deaktiviert. Installiere **MetalLB**:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

# IP-Pool konfigurieren
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.122.100-192.168.122.150
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
```

### 4. Monitoring

Deploy **kube-prometheus-stack** (Prometheus + Grafana):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

### 5. GitOps mit Flux

Install Flux für GitOps Deployments:

```bash
flux bootstrap github \
  --owner=<github-user> \
  --repository=homelab-iac \
  --path=./flux/clusters/development \
  --personal
```

## Zusammenfassung

Du hast jetzt:

- ✅ Funktionierende KVM/libvirt Installation
- ✅ Terraform Setup mit Modulen
- ✅ 1 k3s Control Plane Node
- ✅ 2 k3s Worker Nodes
- ✅ Komplett automatisierte Provisionierung
- ✅ Immutable Infrastructure mit Ignition
- ✅ Infrastructure as Code mit Git

**Workflow für Änderungen:**

1. Code in Git anpassen
2. `terraform plan` - Änderungen prüfen
3. `terraform apply` - Ausführen
4. `kubectl get nodes` - Verifizieren

**Kein SSH, keine manuellen Änderungen, nur Code!**

Das ist **professionelles Infrastructure Management**!
