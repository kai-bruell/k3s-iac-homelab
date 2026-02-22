# nixos-minimal Environment

Deployt eine minimale NixOS-VM auf Proxmox via **nixos-anywhere + disko**.
Dient als Referenz-Environment und Vorlage für weitere NixOS-VMs.

## Architektur

```
tofu apply
  ├── Debian cloud-init Template klonen (Bootstrap-VM)
  │     cloud-init: SSH-Key + qemu-guest-agent installieren
  │     QEMU Guest Agent: DHCP-IP melden
  └── nixos-anywhere (local-exec):
        ├── kexec: VM bootet in NixOS-Installer (kein Hardware-Reboot)
        ├── disko: /dev/sda partitionieren (GPT + GRUB + ext4 root)
        ├── nixos-install: NixOS aus Flake bauen und installieren
        └── Reboot → VM mit statischer IP aus nixos/hosts/nixos-minimal/default.nix
```

## Einmalige Vorbereitung auf Proxmox

Diese Schritte werden **einmalig manuell** durchgeführt. Danach läuft `tofu apply` vollautomatisch.

### 1. Snippets auf local Storage aktivieren

Wird für das cloud-init user-data Snippet benötigt:

```bash
pvesm set local --content snippets,iso,vztmpl,backup
```

### 2. Debian Bootstrap-Template erstellen (VM 9000)

```bash
# Debian 12 Cloud Image herunterladen
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2

# VM anlegen
qm create 9000 --name "debian-cloud-init" --memory 1024 --net0 virtio,bridge=vmbr0

# Disk importieren (local-lvm anpassen falls nötig)
qm importdisk 9000 debian-12-genericcloud-amd64.qcow2 local-lvm

# VM konfigurieren
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0 --ide2 local-lvm:cloudinit --agent 1

# Disk auf gewünschte Größe erweitern (z.B. 20G)
qm resize 9000 scsi0 20G

# Als Template markieren
qm template 9000
```

### 3. SSH-Key generieren (falls noch nicht vorhanden)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab-dev -C "homelab"
```

Den Public Key (`cat ~/.ssh/homelab-dev.pub`) in zwei Dateien eintragen:
- `terraform.tfvars` → `ssh_public_keys`
- `nixos/hosts/nixos-minimal/default.nix` → `users.users.root.openssh.authorizedKeys.keys`

## Konfiguration

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars anpassen (Proxmox-Credentials, IPs, SSH-Keys)
```

Statische IP der VM in `nixos/hosts/nixos-minimal/default.nix` setzen:

```nix
networkConfig = {
  Address = "192.168.178.156/24";  # <-- anpassen
  Gateway = "192.168.178.199";
  DNS     = "192.168.178.199";
};
```

## Deployment

```bash
# Im devbox-Shell (distrobox)
cd terraform/environments/nixos-minimal

tofu init      # einmalig
tofu apply     # VM erstellen + NixOS installieren (~5 min)
```

Nach erfolgreichem Apply:

```bash
ssh -i ~/.ssh/homelab-dev root@192.168.178.156
```

## VM-Disk nachträglich vergrößern

Da `boot.growPartition = true` gesetzt ist, reicht:

```bash
# VM stoppen (Proxmox UI oder: qm stop 300)
qm resize 300 scsi0 30G   # auf Proxmox-Host
# VM starten → Partition wächst automatisch
```

## Neu deployen

```bash
tofu destroy -auto-approve && tofu apply
```

## Dateistruktur

```
terraform/environments/nixos-minimal/
├── README.md                   # diese Datei
├── main.tf                     # Provider + Modul-Aufruf
├── variables.tf                # Variable-Definitionen
├── terraform.tfvars.example    # Vorlage (in Git)
└── terraform.tfvars            # Deine Werte (in .gitignore!)

terraform/modules/nixos-vm/     # Generisches VM-Modul
nixos/hosts/nixos-minimal/      # NixOS-Konfiguration
├── default.nix                 # Hostname, statische IP, SSH-Keys
└── disko.nix                   # Disk-Layout (/dev/sda, GPT, ext4)
nixos/modules/
├── base.nix                    # SSH, QEMU Agent, Nix-Settings
└── hardware-vm.nix             # Kernel-Module, boot.growPartition
```
