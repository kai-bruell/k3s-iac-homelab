# Proxmox Bootstrap-Template erstellen (q35 / Ubuntu)

Das Bootstrap-Template (VM 9002) ist eine **einmalige manuelle Einrichtung** auf dem Proxmox-Host.
Es dient als Ausgangspunkt fuer alle NixOS-VMs mit GPU-Passthrough: Terraform klont dieses Template,
bootet es per cloud-init, und nixos-anywhere ueberschreibt es anschliessend vollstaendig mit NixOS.

> **Warum Ubuntu statt Debian?** Ubuntu 24.04 Cloud Images enthalten qemu-guest-agent und cloud-init
> vorinstalliert und aktiv – Debian genericcloud deaktiviert cloud-init nach dem ersten Boot ohne
> Datasource, was den Terraform-Workflow blockiert.
>
> **Warum q35?** GPU-Passthrough mit `pcie=true` erfordert den q35 Machine-Typ. Das Template muss
> daher nativ als q35 erstellt werden – ein nachtraeglicher Wechsel via Terraform wuerde cloud-init
> brechen (q35 hat keinen IDE-Controller, Proxmox cloud-init nutzt standardmaessig ide2).

## Voraussetzungen

- SSH-Zugang zum Proxmox-Host
- Internetzugang vom Proxmox-Host aus

---

## Schritt 1: Ubuntu Cloud Image herunterladen

```bash
cd /tmp
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

---

## Schritt 2: VM erstellen

```bash
qm create 9002 \
  --name ubuntu-2404-q35 \
  --memory 1024 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --machine q35 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1 \
  --ostype l26
```

---

## Schritt 3: Disk importieren und konfigurieren

```bash
qm importdisk 9002 /tmp/noble-server-cloudimg-amd64.img local-lvm

qm set 9002 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9002-disk-0

# Disk-Groesse auf 40G erhoehen (20G reicht nicht fuer NixOS + NVIDIA-Treiber)
qm resize 9002 scsi0 40G

qm set 9002 --boot order=scsi0
```

---

## Schritt 4: Cloud-Init konfigurieren

```bash
# sata1 statt ide2 – q35 hat keinen IDE-Controller
qm set 9002 --sata1 local-lvm:cloudinit

qm set 9002 --ciuser root
qm set 9002 --ipconfig0 ip=dhcp
```

---

## Schritt 5: In Template umwandeln

```bash
qm template 9002
```

---

## Ergebnis

Template VM 9002 ist bereit. Terraform klont dieses Template, injiziert SSH-Keys via cloud-init,
und nixos-anywhere installiert NixOS auf der laufenden VM.

`bootstrap_template_id = 9002` in `terraform/environments/videoediting/terraform.tfvars`.

Referenz: `terraform/modules/nixos-vm/main.tf`.
