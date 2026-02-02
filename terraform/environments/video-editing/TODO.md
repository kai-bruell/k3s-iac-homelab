# TODO: NixOS Video-Editing VM

## Ziel
NixOS-Image fuer Proxmox in einer CI/CD Pipeline bauen, statt lokal.

## Vorteile
- Lokale Umgebung bleibt sauber (kein Nix auf Host noetig)
- Reproduzierbar und teamfreundlich
- Passt zum "Cattle"-Ansatz (Infrastructure as Code)

## Naechste Schritte

### 1. GitHub Actions Workflow erstellen
- [ ] `.github/workflows/build-nixos-image.yml` anlegen
- [ ] NixOS Image mit `nixos-generators` bauen
- [ ] Artifact als Release oder in GitHub Artifacts speichern

### 2. Image auf Proxmox deployen
- [ ] Image von GitHub herunterladen (manuell oder per Script)
- [ ] `qmrestore` oder `qm importdisk` nutzen
- [ ] Template erstellen (VM ID 9001)

### 3. Terraform ausfuehren
- [ ] `tofu init && tofu apply`
- [ ] Verifizieren: GNOME, Sunshine, NVIDIA 470

## Beispiel GitHub Actions Workflow

```yaml
name: Build NixOS Video-Editing Image

on:
  push:
    paths:
      - 'terraform/environments/video-editing/nixos/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: cachix/install-nix-action@v27
        with:
          nix_path: nixpkgs=channel:nixos-24.11

      - name: Build Proxmox Image
        run: |
          nix-shell -p nixos-generators --run \
            "nixos-generate -f proxmox -c terraform/environments/video-editing/nixos/configuration.nix -o result"

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: nixos-video-editing
          path: result/
          retention-days: 7
```

## Offene Fragen
- [ ] Soll das Image als GitHub Release veroeffentlicht werden?
- [ ] Automatisches Deployment auf Proxmox (z.B. via SSH in der Pipeline)?
