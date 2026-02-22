# Code Review: nixos-minimal Environment

Reviewer-Checkliste und bekannte Schwachstellen für das nixos-anywhere + disko Setup.

---

## Warnings im `tofu apply` Output

### `warning: unknown setting 'eval-cores'` / `warning: unknown setting 'lazy-trees'`
**Quelle:** Nix-Daemon in der Distrobox liest eine veraltete `nix.conf` mit Optionen, die die
aktuelle Nix-Version nicht mehr kennt.
**Nicht im Repo-Code.** Fix in der Distrobox:
```bash
# Zeigt welche nix.conf geladen wird:
nix show-config | grep config-file
# Veraltete Einträge entfernen
```

### `accepted connection from pid ..., user user`
Normales Nix-Daemon-Log, landet fälschlicherweise auf stderr. Kein Problem, nur Rauschen.

### `Pseudo-terminal will not be allocated because stdin is not a terminal`
SSH-Warnung weil nixos-anywhere ohne TTY läuft (in `local-exec`). Harmlos, funktioniert korrekt.

### `Warning: Permanently added '...' (ED25519) to the list of known hosts`
Mehrfach, weil nixos-anywhere für jeden SSH-Schritt (Upload, kexec, install) eine neue
Verbindung aufbaut und `StrictHostKeyChecking=no` intern verwendet. Kein Bug.

---

## Zu prüfende Bereiche

### 1. Terraform

#### `terraform/modules/nixos-vm/main.tf`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 125 | Kommentar sagt `partitioniert /dev/vda` — tatsächlich wird `/dev/sda` (scsi0) verwendet | Niedrig |
| 114–117 | `local.vm_ip = [...][0]` — kein Fallback wenn `ipv4_addresses` leer ist. Führt zu unklarem `index out of range`-Fehler wenn QEMU Agent noch nicht bereit ist | Mittel |
| 132–147 | `null_resource` + `local-exec` ist ein Terraform-Anti-Pattern: kein echter State, schwer zu debuggen, kein Retry. Für nixos-anywhere gibt es aktuell keine bessere Alternative — **dokumentieren**, nicht beheben | Niedrig |
| 139–146 | nixos-anywhere bekommt kein explizites `--ssh-option "StrictHostKeyChecking=no"`. Funktioniert weil nixos-anywhere das intern setzt, aber nicht offensichtlich | Niedrig |

#### `terraform/environments/nixos-minimal/variables.tf`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 23 | `proxmox_insecure = true` als **Default** — TLS-Verifikation ist standardmäßig deaktiviert. Sollte `false` sein, mit Hinweis wie Self-Signed-Certs konfiguriert werden | Mittel |

#### `terraform/environments/nixos-minimal/README.md`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 104 | `qm resize 300 scsi0 30G` — VM-ID 300 ist hardcoded. Sollte `<vm-id>` Platzhalter sein | Niedrig |

---

### 2. NixOS Konfiguration

#### `nixos/hosts/nixos-minimal/default.nix`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 11 | `{ modulesPath, ... }:` — `modulesPath` wird in dieser Datei nicht verwendet. Kann zu `{ ... }:` vereinfacht werden | Niedrig |

#### `nixos/hosts/nixos-minimal/disko.nix`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 3–4 | Kommentar oben erwähnt noch den alten Kontext (Überreste aus dem virtio0-Ansatz) | Niedrig |

#### `nixos/modules/hardware-vm.nix`

| Zeile | Problem | Schwere |
|-------|---------|---------|
| 21 | `"virtio_blk" # fuer /dev/vda (virtio0 disk interface)` — Kommentar stimmt nicht mehr. Disk ist `/dev/sda` (scsi0, via `virtio_scsi` + `sd_mod`) | Niedrig |

---

### 3. Architektur / Prozess

#### SSH-Keys müssen manuell synchron gehalten werden

SSH Public Keys müssen an **zwei Stellen** identisch sein:
1. `terraform.tfvars` → `ssh_public_keys` (für cloud-init auf Bootstrap-Debian)
2. `nixos/hosts/<host>/default.nix` → `users.users.root.openssh.authorizedKeys.keys` (finales NixOS)

Wenn sie divergieren, schlägt der SSH-Login nach nixos-anywhere fehl.
**Kein technischer Mechanismus erzwingt die Konsistenz** — nur Konvention und Dokumentation.

#### Statische IP ist kein Single Source of Truth

Die VM-IP ist in `nixos/hosts/nixos-minimal/default.nix` definiert.
Terraform kennt sie **nicht** — der `ssh_hint`-Output sagt `<static-ip-aus-flake>`.
Bei Fehlern oder nach dem Deploy muss der Nutzer die IP aus dem NixOS-Flake nachschlagen.

---

## Was explizit **nicht** gefixt werden muss

| Punkt | Begründung |
|-------|------------|
| `null_resource` für nixos-anywhere | Keine bessere Terraform-native Alternative. Ist dokumentiert. |
| `proxmox_insecure = true` in `terraform.tfvars` | Homelab mit Self-Signed-Cert — bewusste Entscheidung |
| Root-SSH-Zugang | nixos-anywhere benötigt Root-SSH. `prohibit-password` + Key-only ist korrekt |
| `StrictHostKeyChecking` intern in nixos-anywhere | Wird von nixos-anywhere selbst korrekt gesetzt |

---

## Kurzübersicht: Schnelle Fixes

```
# hardware-vm.nix Zeile 21:
"virtio_blk" # fuer /dev/vda  →  "virtio_blk"

# main.tf Zeile 125:
partitioniert /dev/vda  →  partitioniert /dev/sda

# default.nix Zeile 11:
{ modulesPath, ... }:  →  { ... }:

# variables.tf (environment) Zeile 23:
default = true  →  default = false  (proxmox_insecure)

# README.md Zeile 104:
qm resize 300 scsi0 30G  →  qm resize <vm-id> scsi0 <size>G
```
