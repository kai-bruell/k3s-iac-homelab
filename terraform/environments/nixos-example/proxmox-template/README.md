# Proxmox Bootstrap-Template erstellen

Das Bootstrap-Template (VM 9000) ist eine **einmalige manuelle Einrichtung** auf dem Proxmox-Host.
Es dient als Ausgangspunkt fuer alle NixOS-VMs: Terraform klont dieses Template, bootet es per
cloud-init, und nixos-anywhere ueberschreibt es anschliessend vollstaendig mit NixOS.

## Voraussetzungen

- SSH-Zugang zum Proxmox-Host (z.B. `ssh root@192.168.178.10`)
- Internetzugang vom Proxmox-Host aus

---

## Schritt 1: Debian Genericcloud Image herunterladen

```bash
# Auf dem Proxmox-Host ausfuehren
cd /tmp

# Aktuelles Debian 12 (Bookworm) genericcloud Image herunterladen
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

> **Warum genericcloud?** Das Image enthaelt qemu-guest-agent und cloud-init vorinstalliert –
> beides wird von Terraform (bpg/proxmox Provider) und nixos-anywhere benoetigt.

---

## Schritt 2: VM erstellen

```bash
# VM mit ID 9000 erstellen
qm create 9000 \
  --name debian-cloud-init \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1 \
  --ostype l26
```

---

## Schritt 3: Disk importieren und konfigurieren

```bash
# Heruntergeladenes Image als Disk importieren (local-lvm anpassen falls noetig)
qm importdisk 9000 /tmp/debian-12-genericcloud-amd64.qcow2 local-lvm

# Importierte Disk als scsi0 einhaengen
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Disk-Groesse auf 20G erhoehen (wichtig: muss gross genug fuer NixOS sein)
qm resize 9000 scsi0 20G

# Boot von scsi0
qm set 9000 --boot c --bootdisk scsi0
```

---

## Schritt 4: Cloud-Init konfigurieren

```bash
# Cloud-Init Drive hinzufuegen
qm set 9000 --ide2 local-lvm:cloudinit

# Cloud-Init Basis-Konfiguration (wird von Terraform pro VM ueberschrieben)
qm set 9000 --ciuser root
qm set 9000 --ipconfig0 ip=dhcp
```

---

## Schritt 5: In Template umwandeln

```bash
# VM als Template markieren (kann danach nicht mehr gestartet werden)
qm template 9000
```

---

## Ergebnis

Template VM 9000 ist bereit. Terraform (bpg/proxmox Provider) klont dieses Template per
`full_clone = true`, injiziert SSH-Keys und statische IP via cloud-init, und nixos-anywhere
installiert NixOS auf der laufenden VM.

Referenz: `terraform/modules/nixos-vm/main.tf`, Variable `bootstrap_template_id` (default: `9000`).
