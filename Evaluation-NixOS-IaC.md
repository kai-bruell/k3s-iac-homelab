# Evaluation: NixOS auf Proxmox mit IaC

## Das Problem mit dem aktuellen Setup

Das aktuelle Setup (Packer Base-Template → Terraform Clone → Provisioner führt `nixos-rebuild` via SSH aus) hat grundlegende Probleme:

- **Zu viele bewegliche Teile:** Packer, Terraform, Shell-Script, SSH-Timing, Interface-Namen
- **Imperativ statt deklarativ:** `nixos-rebuild` via SSH-Provisioner ist kein NixOS-Gedanke
- **Fragil:** Interface-Name hardcodiert, SSH-Agent-Probleme, Timing-Issues
- **Langsam:** VM muss Pakete beim Deploy aus dem Internet laden

---

## Wie machen das andere? (2024–2025)

### Option 1: nixos-anywhere + Terraform ⭐ Empfohlen

**Idee:** Terraform erstellt eine leere VM (beliebiges Linux oder NixOS minimal ISO). `nixos-anywhere` verbindet sich per SSH, bootet via **kexec** in einen NixOS-Installer und installiert das fertige System aus dem Flake.

**Flow:**
```
Terraform
  └── bpg/proxmox: erstellt VM (aus beliebigem Linux / ISO)
  └── nixos-anywhere Terraform-Modul: deployt NixOS via SSH + kexec
        └── disko: partitioniert Disk deklarativ (in Nix definiert)
        └── nixos-rebuild: installiert finales System aus Flake
        └── Reboot → fertige VM
```

**Was man braucht:**
- NixOS Flake mit `nixosConfigurations.mein-host`
- disko-Konfiguration (Disk-Layout in Nix)
- Terraform mit bpg/proxmox + nixos-anywhere Modul

**Terraform sieht dann so aus:**
```hcl
module "nixos-anywhere" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr = ".#ollama"
  target_host       = proxmox_virtual_environment_vm.vm.ipv4_addresses[0]
  instance_id       = proxmox_virtual_environment_vm.vm.id
}
```

**Vorteile:**
- Kein Packer nötig
- Kein Shell-Script-Provisioner
- Disk-Layout deklarativ in Nix
- Einzige Source of Truth: das Flake

**Nachteile:**
- Erster Deploy dauert länger (lädt kexec-Image)
- Braucht kexec-Support auf der VM (Standard bei x86_64)
- Min. 1 GB RAM auf der VM während Installation

**Ressourcen:**
- https://github.com/nix-community/nixos-anywhere
- https://nix-community.github.io/nixos-anywhere/howtos/terraform.html
- https://github.com/nix-community/disko

---

### Option 2: nixos-generators → Proxmox Image

**Idee:** Baut lokal ein fertiges Proxmox-VMA-Image aus dem Flake. Terraform importiert es als Template, klont und startet.

**Flow:**
```
Lokal:
  nixos-generators --format proxmox --flake .#ollama
  → ollama.vma.zst (fertig konfiguriertes Image)

Proxmox:
  qmrestore ollama.vma.zst <vmid>   (oder via Terraform)

Terraform:
  bpg/proxmox: klont Template → VM startet sofort fertig
```

**Vorteile:**
- VM ist sofort nach dem Boot fertig – kein Deploy-Schritt
- Schnellstes Boot-to-Ready
- Komplett offline möglich

**Nachteile:**
- Bei jeder Config-Änderung: Image neu bauen → neues Template → destroy + apply
- Lokaler Build-Schritt außerhalb von Terraform

**Ressourcen:**
- https://github.com/nix-community/nixos-generators

---

### Option 3: Aktuelles Setup (repariert)

Packer Base-Template + Terraform Clone + `nixos-rebuild` via SSH-Provisioner – aber sauber implementiert.

**Macht Sinn wenn:** Man eine generische Base-VM für viele verschiedene VMs will und nicht pro VM-Typ ein eigenes Image bauen möchte.

**Problem bleibt:** NixOS-Rebuild auf der VM braucht Internet, ist langsam und fehleranfällig.

---

## Vergleich

| | nixos-anywhere | nixos-generators | Aktuelles Setup |
|---|---|---|---|
| Packer nötig | ❌ | ❌ | ✅ |
| Shell-Provisioner | ❌ | ❌ | ✅ |
| Config in Nix | ✅ | ✅ | Teilweise |
| Internet auf VM | Nur bei Install | ❌ | ✅ immer |
| Config-Update | `tofu apply` | Image rebuild | `tofu apply` |
| Komplexität | Niedrig | Mittel | Hoch |

---

## Empfehlung

**Für dieses Homelab: nixos-anywhere + Terraform**

Begründung:
- Kein Packer-Build-Step nötig
- Ein Flake als einzige Source of Truth für alle VMs
- Terraform macht das Infra, NixOS macht die Config – saubere Trennung
- nixos-anywhere ist der Community-Standard für genau diesen Anwendungsfall

**Nächste Schritte:**
1. disko-Konfiguration für die VM schreiben (Disk-Layout in Nix)
2. NixOS Flake um `nixosConfigurations` erweitern (mit disko-Modul)
3. Terraform-Modul vereinfachen: nur noch VM erstellen + nixos-anywhere aufrufen
4. Packer-Step entfernen
