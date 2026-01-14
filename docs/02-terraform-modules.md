
# OpenTofu Module Deep Dive

## Modul-Architektur

Unser Setup hat drei Ebenen:

```
Ebene 3: environments/development/
         ├── Definiert konkrete Werte (1 server, 2 agents, SSH keys)
         ├── Nutzt ↓

Ebene 2: modules/k3s-cluster/
         ├── Orchestriert Server + Agents
         ├── Generiert k3s Token
         ├── Nutzt ↓

Ebene 1: modules/flatcar-vm/
         └── Erstellt einzelne VM mit Ignition
```

**Warum Module?**

- **DRY** (Don't Repeat Yourself) - Code nicht kopieren
- **Abstraktion** - Komplexität verstecken
- **Wiederverwendbarkeit** - Gleicher Code für Server & Agents
- **Separation of Concerns** - Jedes Modul hat eine Aufgabe
- **Testbarkeit** - Module einzeln testen

> **Hinweis:** OpenTofu ist ein Open-Source Fork von Terraform und verwendet die gleiche HCL-Syntax. Alle Terraform-Konzepte (Module, Provider, State) funktionieren identisch.

## Modul 1: flatcar-vm

**Verantwortung:** Eine einzelne Flatcar VM erstellen mit Ignition Config

### Inputs (variables.tf)

```hcl
# Basis-Variablen
variable "cluster_name" {
  description = "Name des Clusters (Präfix für Ressourcen)"
  type        = string
}

variable "vm_name" {
  description = "Name der virtuellen Maschine"
  type        = string
}

variable "base_image_path" {
  description = "Pfad zum Flatcar Base Image"
  type        = string
}

variable "pool_path" {
  description = "Pfad zum libvirt Storage Pool"
  type        = string
  default     = "/var/lib/libvirt/images"
}

# Butane Config
variable "butane_config_path" {
  description = "Pfad zur Butane Config Template-Datei"
  type        = string
}

# SSH
variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

# VM Ressourcen
variable "vcpu" {
  description = "Anzahl virtueller CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

# Netzwerk
variable "network_name" {
  description = "Name des libvirt Netzwerks"
  type        = string
  default     = "default"
}

variable "graphics_type" {
  description = "Grafik-Typ (spice oder vnc)"
  type        = string
  default     = "spice"
}

# k3s-spezifisch
variable "k3s_role" {
  description = "k3s Rolle (server oder agent)"
  type        = string
  validation {
    condition     = contains(["server", "agent"], var.k3s_role)
    error_message = "k3s_role muss 'server' oder 'agent' sein."
  }
}

variable "k3s_token" {
  description = "k3s Cluster Token"
  type        = string
  sensitive   = true
}

variable "k3s_server_url" {
  description = "k3s Server URL (nur für Agents)"
  type        = string
  default     = ""
}

variable "extra_butane_config" {
  description = "Zusätzliche Butane Config (YAML)"
  type        = string
  default     = ""
}
```

**Wichtige Konzepte:**

1. **Validation:**
```hcl
validation {
  condition     = contains(["server", "agent"], var.k3s_role)
  error_message = "k3s_role muss 'server' oder 'agent' sein."
}
```
OpenTofu validiert Inputs zur Plan-Zeit!

2. **Sensitive:**
```hcl
variable "k3s_token" {
  sensitive = true  # Wird nicht in Logs/Output gezeigt
}
```

3. **Defaults:**
```hcl
variable "pool_path" {
  default = "/var/lib/libvirt/images"
}
```
Optional - kann überschrieben werden.

### Resources (main.tf)

#### 1. Required Providers

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13"
    }
  }
}
```

**Provider Versions:**
- `~> 0.7` bedeutet `>= 0.7.0, < 0.8.0`
- Erlaubt Patch-Updates, aber keine Breaking Changes

#### 2. Storage Pool

```hcl
resource "libvirt_pool" "vm_pool" {
  name = "${var.cluster_name}-pool"
  type = "dir"
  path = var.pool_path
}
```

**Was ist ein Storage Pool?**

Ein logischer Container für VM-Disks. Ähnlich wie Docker Volumes oder LVM Volume Groups.

**Pool-Typen:**
- `dir` - Verzeichnis auf dem Host
- `lvm` - LVM Volume Group
- `zfs` - ZFS Pool
- `rbd` - Ceph RBD

Wir nutzen `dir` für Simplicity.

**Warum pro Cluster ein Pool?**

- Einfache Bereinigung: `terraform destroy` löscht alles
- Isolation zwischen Projekten
- Quotas/Monitoring pro Pool möglich

#### 3. Base Image Volume

```hcl
resource "libvirt_volume" "base" {
  name   = "${var.cluster_name}-base.img"
  source = var.base_image_path
  pool   = libvirt_pool.vm_pool.name
  format = "qcow2"
}
```

**Was passiert hier?**

1. Terraform kopiert Flatcar Image in den Pool
2. Konvertiert zu qcow2 (falls nötig)
3. Dieses Image wird NIE verändert

**Warum ein Base Image?**

- Alle VMs teilen sich das gleiche Base Image
- Spart Speicherplatz durch Copy-on-Write
- Schnellere VM-Erstellung (kein erneutes Kopieren)

#### 4. VM-spezifisches Volume (Copy-on-Write)

```hcl
resource "libvirt_volume" "vm" {
  name           = "${var.vm_name}-${substr(md5(libvirt_ignition.ignition.id), 0, 8)}.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool           = libvirt_pool.vm_pool.name
  format         = "qcow2"
}
```

**Copy-on-Write (CoW) erklärt:**

```
Base Image (read-only):
├── /usr/bin/     (100 MB)
├── /usr/lib/     (500 MB)
└── /boot/        (50 MB)
    ↓ base_volume_id
VM Volume (nur Deltas):
├── /etc/hostname (1 KB)   ← Nur das!
├── /home/core/   (10 KB)
└── /var/log/     (5 KB)

Gesamt: 650 MB Base + 16 KB Delta statt 650 MB pro VM!
```

**Name mit MD5 Hash:**
```hcl
name = "${var.vm_name}-${substr(md5(libvirt_ignition.ignition.id), 0, 8)}.qcow2"
       # k3s-dev-server-1-a3b4c5d6.qcow2
```

**Warum?**

Wenn Ignition Config ändert → Neues Volume erstellt → Alte VM bleibt intakt!

**Terraform Replace Logic:**
1. Ignition Config ändert → `ignition.id` ändert sich
2. MD5 Hash ändert sich → Volume-Name ändert sich
3. Volume wird neu erstellt → VM wird neu erstellt

#### 5. Butane → Ignition Kompilierung

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

**Schritt für Schritt:**

1. **templatefile()** liest Butane YAML:
```yaml
hostname: ${hostname}
ssh_keys: ${ssh_keys}
```

2. Ersetzt Variablen:
```yaml
hostname: k3s-dev-server-1
ssh_keys: ["ssh-ed25519 AAAA..."]
```

3. **ct_config** Data Source kompiliert zu Ignition JSON
4. **strict = true** - Fehler bei ungültiger Config

**Data Source vs Resource:**
- **Resource** - Erstellt etwas (VM, Volume)
- **Data Source** - Liest/Konvertiert etwas (Config kompilieren, IP nachschlagen)

#### 6. Ignition Resource

```hcl
resource "libvirt_ignition" "ignition" {
  name    = "${var.vm_name}-ignition"
  content = data.ct_config.vm_config.rendered
  pool    = libvirt_pool.vm_pool.name
}
```

**Was passiert?**

libvirt erstellt ein **ISO-Image** mit der Ignition JSON im Pool:

```
/var/lib/libvirt/images/k3s-dev-pool/
├── k3s-dev-base.img
├── k3s-dev-server-1-a3b4c5d6.qcow2
└── k3s-dev-server-1-ignition.iso  ← Hier!
```

Die VM bootet mit diesem ISO als CD-ROM attached.

#### 7. Virtual Machine

```hcl
resource "libvirt_domain" "vm" {
  name   = var.vm_name
  vcpu   = var.vcpu
  memory = var.memory

  coreos_ignition = libvirt_ignition.ignition.id

  disk {
    volume_id = libvirt_volume.vm.id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = var.graphics_type
    listen_type = "address"
  }
}
```

**Wichtige Attribute:**

1. **coreos_ignition:**
```hcl
coreos_ignition = libvirt_ignition.ignition.id
```
Hängt Ignition ISO als CD-ROM an die VM!

2. **wait_for_lease:**
```hcl
network_interface {
  network_name   = var.network_name
  wait_for_lease = true  # ← Wartet auf DHCP IP!
}
```
OpenTofu wartet bis VM eine IP bekommt. Dann ist `libvirt_domain.vm.network_interface[0].addresses[0]` verfügbar.

3. **console:**
```hcl
console {
  type        = "pty"
  target_port = "0"
  target_type = "serial"
}
```
Serial Console für Debugging:
```bash
virsh console k3s-dev-server-1
```

4. **graphics:**
```hcl
graphics {
  type        = var.graphics_type  # spice oder vnc
  listen_type = "address"
}
```
Ermöglicht virt-manager GUI-Zugriff.

### Outputs (outputs.tf)

```hcl
output "vm_id" {
  description = "ID der VM"
  value       = libvirt_domain.vm.id
}

output "vm_name" {
  description = "Name der VM"
  value       = libvirt_domain.vm.name
}

output "vm_ip" {
  description = "IP-Adresse der VM"
  value       = try(libvirt_domain.vm.network_interface[0].addresses[0], "")
}
```

**try() Funktion:**
```hcl
value = try(libvirt_domain.vm.network_interface[0].addresses[0], "")
```

Wenn IP noch nicht verfügbar → Return `""` statt Fehler.

**Outputs verwenden:**

```hcl
module "vm" {
  source = "./modules/flatcar-vm"
  # ...
}

output "ip" {
  value = module.vm.vm_ip  # ← Zugriff auf Modul-Output
}
```

## Modul 2: k3s-cluster

**Verantwortung:** Orchestriert mehrere VMs zu einem k3s Cluster

### Inputs (variables.tf)

```hcl
variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
}

variable "base_image_path" {
  description = "Pfad zum Flatcar Base Image"
  type        = string
}

variable "pool_path" {
  description = "Pfad zum libvirt Storage Pool"
  type        = string
  default     = "/var/lib/libvirt/images"
}

variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

# Server-Konfiguration
variable "server_count" {
  description = "Anzahl k3s Server Nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.server_count >= 1 && var.server_count <= 5
    error_message = "server_count muss zwischen 1 und 5 liegen."
  }
}

variable "server_vcpu" {
  description = "vCPUs pro Server Node"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "RAM in MB pro Server Node"
  type        = number
  default     = 4096
}

variable "server_butane_config_path" {
  description = "Pfad zur Butane Config für Server Nodes"
  type        = string
}

# Agent-Konfiguration
variable "agent_count" {
  description = "Anzahl k3s Agent Nodes"
  type        = number
  default     = 2
}

variable "agent_vcpu" {
  description = "vCPUs pro Agent Node"
  type        = number
  default     = 2
}

variable "agent_memory" {
  description = "RAM in MB pro Agent Node"
  type        = number
  default     = 2048
}

variable "agent_butane_config_path" {
  description = "Pfad zur Butane Config für Agent Nodes"
  type        = string
}

# Netzwerk
variable "network_name" {
  description = "Name des libvirt Netzwerks"
  type        = string
  default     = "default"
}

variable "graphics_type" {
  description = "Grafik-Typ (spice oder vnc)"
  type        = string
  default     = "spice"
}

# k3s-Konfiguration
variable "k3s_token" {
  description = "k3s Cluster Token (wird generiert falls leer)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "first_server_extra_config" {
  description = "Zusätzliche Config für ersten Server Node"
  type        = string
  default     = ""
}

variable "server_extra_config" {
  description = "Zusätzliche Config für weitere Server Nodes"
  type        = string
  default     = ""
}

variable "agent_extra_config" {
  description = "Zusätzliche Config für Agent Nodes"
  type        = string
  default     = ""
}
```

**Wichtige Validations:**

```hcl
validation {
  condition     = var.server_count >= 1 && var.server_count <= 5
  error_message = "server_count muss zwischen 1 und 5 liegen."
}
```

Verhindert ungültige Werte zur Plan-Zeit!

### Resources (main.tf)

#### 1. Random Token Generator

```hcl
resource "random_password" "k3s_token" {
  count   = var.k3s_token == "" ? 1 : 0
  length  = 48
  special = false
}

locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result
}
```

**Conditional Resource:**
```hcl
count = var.k3s_token == "" ? 1 : 0
```

- Wenn `k3s_token` leer → Erstelle random_password
- Wenn gesetzt → Erstelle NICHTS (count = 0)

**Local Value:**
```hcl
locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result
}
```

- Wenn `var.k3s_token` gesetzt → Nutze das
- Sonst → Nutze generierten Token

**Warum [0]?**

```hcl
random_password.k3s_token[0].result
                         # ↑ Zugriff auf erstes Element (count = 1)
```

count erstellt eine Liste von Resources. Bei count=1 → Liste mit einem Element.

#### 2. Server & Agent URLs

```hcl
locals {
  k3s_token       = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result
  first_server_ip = module.k3s_servers[0].vm_ip
  k3s_server_url  = "https://${local.first_server_ip}:6443"
}
```

**Wichtig:**
- `first_server_ip` kommt vom **ersten** Server-Modul
- `k3s_server_url` wird an Agents übergeben

#### 3. Server Nodes (count Loop)

```hcl
module "k3s_servers" {
  source = "../flatcar-vm"
  count  = var.server_count

  cluster_name        = var.cluster_name
  vm_name             = "${var.cluster_name}-server-${count.index + 1}"
  base_image_path     = var.base_image_path
  pool_path           = var.pool_path
  butane_config_path  = var.server_butane_config_path
  ssh_keys            = var.ssh_keys
  vcpu                = var.server_vcpu
  memory              = var.server_memory
  network_name        = var.network_name
  graphics_type       = var.graphics_type

  k3s_role       = "server"
  k3s_token      = local.k3s_token
  k3s_server_url = count.index == 0 ? "" : local.k3s_server_url

  extra_butane_config = count.index == 0 ? var.first_server_extra_config : var.server_extra_config
}
```

**count Loop erklärt:**

```hcl
count = var.server_count  # z.B. 3
```

Erstellt 3 Instanzen des Moduls:
- `module.k3s_servers[0]` - Erster Server
- `module.k3s_servers[1]` - Zweiter Server
- `module.k3s_servers[2]` - Dritter Server

**count.index:**

```hcl
vm_name = "${var.cluster_name}-server-${count.index + 1}"
          # k3s-dev-server-1 (count.index = 0, +1 = 1)
          # k3s-dev-server-2 (count.index = 1, +1 = 2)
          # k3s-dev-server-3 (count.index = 2, +1 = 3)
```

**Conditional für ersten Server:**

```hcl
k3s_server_url = count.index == 0 ? "" : local.k3s_server_url
```

- Erster Server (index 0): `k3s_server_url = ""` → Standalone Mode
- Weitere Server (index > 0): `k3s_server_url = "https://..."` → Join Cluster

**Warum?**

Erster Server nutzt `--cluster-init` (embedded etcd).
Weitere Server joinen mit `--server` Flag.

#### 4. Agent Nodes

```hcl
module "k3s_agents" {
  source = "../flatcar-vm"
  count  = var.agent_count

  cluster_name        = var.cluster_name
  vm_name             = "${var.cluster_name}-agent-${count.index + 1}"
  base_image_path     = var.base_image_path
  pool_path           = var.pool_path
  butane_config_path  = var.agent_butane_config_path
  ssh_keys            = var.ssh_keys
  vcpu                = var.agent_vcpu
  memory              = var.agent_memory
  network_name        = var.network_name
  graphics_type       = var.graphics_type

  k3s_role       = "agent"
  k3s_token      = local.k3s_token
  k3s_server_url = local.k3s_server_url

  extra_butane_config = var.agent_extra_config

  depends_on = [module.k3s_servers]
}
```

**depends_on:**
```hcl
depends_on = [module.k3s_servers]
```

Agents werden **erst erstellt** nachdem **alle Server** fertig sind!

**Warum?**

```hcl
k3s_server_url = local.k3s_server_url
                 # Braucht local.first_server_ip
                 # Die kommt von module.k3s_servers[0].vm_ip
```

OpenTofu muss warten bis Server eine IP hat!

### Outputs (outputs.tf)

```hcl
output "k3s_token" {
  description = "k3s Cluster Token"
  value       = local.k3s_token
  sensitive   = true
}

output "server_ips" {
  description = "IP-Adressen der k3s Server Nodes"
  value       = [for server in module.k3s_servers : server.vm_ip]
}

output "agent_ips" {
  description = "IP-Adressen der k3s Agent Nodes"
  value       = [for agent in module.k3s_agents : agent.vm_ip]
}

output "first_server_ip" {
  description = "IP des ersten Server Nodes (für kubeconfig)"
  value       = local.first_server_ip
}

output "k3s_server_url" {
  description = "k3s API Server URL"
  value       = local.k3s_server_url
}
```

**for Expression:**

```hcl
[for server in module.k3s_servers : server.vm_ip]
# ["192.168.122.10", "192.168.122.11", "192.168.122.12"]
```

Iteriert über alle Server-Module und sammelt IPs in eine Liste.

## Environment: development

**Verantwortung:** Konkrete Werte für Development-Environment

### Main Config (main.tf)

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = var.cluster_name
  base_image_path = var.base_image_path
  pool_path = var.pool_path
  ssh_keys = var.ssh_keys

  # Server Nodes
  server_count = var.server_count
  server_vcpu = var.server_vcpu
  server_memory = var.server_memory
  server_butane_config_path = var.server_butane_config_path

  # Agent Nodes
  agent_count = var.agent_count
  agent_vcpu = var.agent_vcpu
  agent_memory = var.agent_memory
  agent_butane_config_path = var.agent_butane_config_path

  # Netzwerk
  network_name = var.network_name
  graphics_type = var.graphics_type

  # k3s Config
  k3s_token = var.k3s_token
}
```

**Provider Configuration:**

```hcl
provider "libvirt" {
  uri = var.libvirt_uri  # "qemu:///system"
}
```

libvirt Connection URI:
- `qemu:///system` - System-wide VMs (braucht root/sudo)
- `qemu:///session` - User-specific VMs
- `qemu+ssh://user@host/system` - Remote libvirt

### Variables (variables.tf)

Passthrough-Variablen für Modul, mit Defaults für Development:

```hcl
variable "cluster_name" {
  description = "Name des k3s Clusters"
  type        = string
  default     = "k3s-dev"
}

variable "server_count" {
  description = "Anzahl k3s Server Nodes"
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "Anzahl k3s Agent Nodes"
  type        = number
  default     = 2
}
```

### terraform.tfvars.example

Beispiel-Werte für User:

```hcl
# libvirt Connection
libvirt_uri = "qemu:///system"

# Cluster Name
cluster_name = "k3s-dev"

# Flatcar Base Image
# Download: wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2
base_image_path = "/home/user/Downloads/flatcar_production_qemu_image.img"

# Storage Pool
pool_path = "/var/lib/libvirt/images"

# SSH Keys
ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@hostname"
]

# Server Nodes
server_count  = 1
server_vcpu   = 2
server_memory = 4096

# Agent Nodes
agent_count  = 2
agent_vcpu   = 2
agent_memory = 2048

# Network
network_name  = "default"
graphics_type = "spice"

# k3s Token (optional - wird automatisch generiert)
# k3s_token = "my-secret-token"
```

**User macht:**
```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # SSH Keys eintragen
tofu plan
```

### Outputs (outputs.tf)

```hcl
output "k3s_token" {
  description = "k3s Cluster Token"
  value       = module.k3s_cluster.k3s_token
  sensitive   = true
}

output "server_ips" {
  description = "IP-Adressen der k3s Server Nodes"
  value       = module.k3s_cluster.server_ips
}

output "agent_ips" {
  description = "IP-Adressen der k3s Agent Nodes"
  value       = module.k3s_cluster.agent_ips
}

output "k3s_server_url" {
  description = "k3s API Server URL"
  value       = module.k3s_cluster.k3s_server_url
}

output "kubeconfig_command" {
  description = "Befehl zum Abrufen der kubeconfig"
  value       = "scp core@${module.k3s_cluster.first_server_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev-config"
}
```

**kubeconfig_command:**

Zeigt User direkt den Befehl zum kubeconfig Download:

```bash
tofu output kubeconfig_command
# scp core@192.168.122.10:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev-config
```

## OpenTofu Flow Visualisiert

### Apply Flow

```
tofu apply
    ↓
1. Provider initialisiert (libvirt, ct)
    ↓
2. k3s_cluster Modul
    ├─→ Generiert k3s_token (falls leer)
    │
    ├─→ Server Modul [0] (erster Server)
    │   ├─→ Erstellt Storage Pool
    │   ├─→ Kopiert Base Image
    │   ├─→ Kompiliert Butane → Ignition
    │   ├─→ Erstellt Ignition ISO
    │   ├─→ Erstellt VM Volume (CoW)
    │   ├─→ Startet VM
    │   └─→ Wartet auf IP (192.168.122.10)
    │
    ├─→ Server Modul [1..n] (weitere Server, falls server_count > 1)
    │   └─→ Joinen zu Server [0]
    │
    └─→ Agent Module [0..n]
        ├─→ Wartet bis Server fertig (depends_on)
        ├─→ Nutzt first_server_ip für k3s_server_url
        └─→ Erstellt Agents parallel
    ↓
3. VMs booten
    ├─→ Flatcar liest Ignition
    ├─→ Konfiguriert System
    ├─→ install-k3s.service startet
    └─→ k3s installiert & startet
    ↓
4. Outputs anzeigen
```

### Dependency Graph

```
random_password.k3s_token
         ↓
module.k3s_servers[0]
         ↓
    ├─→ libvirt_pool.vm_pool
    ├─→ libvirt_volume.base
    ├─→ data.ct_config.vm_config
    ├─→ libvirt_ignition.ignition
    ├─→ libvirt_volume.vm
    └─→ libvirt_domain.vm
         ↓
local.first_server_ip
local.k3s_server_url
         ↓
module.k3s_agents[*]
         ↓ (depends_on)
    Agents starten
```

## Best Practices

### 1. Module Outputs nutzen

**Gut:**
```hcl
module "vm" {
  source = "./modules/flatcar-vm"
  # ...
}

resource "other_resource" "example" {
  ip = module.vm.vm_ip  # ← Nutze Modul-Output
}
```

**Schlecht:**
```hcl
# Direkter Zugriff auf interne Resource
ip = module.vm.libvirt_domain.vm.network_interface[0].addresses[0]
# ❌ Bricht bei Modul-Änderungen!
```

### 2. depends_on nur wenn nötig

**Gut:**
```hcl
# Implizite Dependency durch Referenz
k3s_server_url = local.first_server_ip  # Terraform weiß: Warte auf Server!
```

**Nur explizit wenn keine Referenz:**
```hcl
depends_on = [module.k3s_servers]  # Keine direkte Referenz → explizit
```

### 3. Validations nutzen

**Gut:**
```hcl
variable "server_count" {
  type = number
  validation {
    condition     = var.server_count >= 1 && var.server_count <= 5
    error_message = "server_count muss zwischen 1 und 5 liegen."
  }
}
```

Fehler zur **tofu plan-Zeit** statt zur **tofu apply-Zeit**!

### 4. Sensitive markieren

**Gut:**
```hcl
variable "k3s_token" {
  type      = string
  sensitive = true  # ← Nicht in Logs!
}
```

### 5. Defaults in Modulen, Overrides in Environments

**Modul:**
```hcl
variable "vcpu" {
  type    = number
  default = 2  # Sinnvoller Default
}
```

**Environment:**
```hcl
module "cluster" {
  vcpu = 4  # Override für Production
}
```

## Zusammenfassung

**Modul-Hierarchie:**

```
flatcar-vm (Einzelne VM)
    ↑ verwendet von
k3s-cluster (Orchestriert Server + Agents)
    ↑ verwendet von
development (Konkrete Werte)
```

**Key Concepts:**

- **count** - Mehrere Instanzen eines Moduls
- **for expressions** - Listen transformieren
- **locals** - Berechnete Werte
- **depends_on** - Explizite Dependencies
- **conditional resources** - `count = condition ? 1 : 0`
- **templatefile()** - Variablen in Templates ersetzen
- **Data Sources** - Lesen/Konvertieren statt Erstellen
- **try()** - Fehler abfangen

**OpenTofu Execution:**

1. `tofu init` - Provider herunterladen
2. `tofu plan` - Änderungen berechnen
3. `tofu apply` - Änderungen ausführen
4. `tofu output` - Ergebnisse anzeigen

**Module Vorteile:**

- Code-Wiederverwendung
- Abstraktion
- Wartbarkeit
- Testbarkeit
- Versionierung


***Hier solltest du nochmal kontrollieren ob auch wirklich das noch aktuell ist zur Terraform konfiguration.
