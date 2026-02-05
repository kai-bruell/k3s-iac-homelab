#!/bin/bash
set -euo pipefail

# =============================================================================
# NixOS Video-Editing VM - Build & Deploy Pipeline
# =============================================================================
# Dieses Skript:
# 1. Prueft ob Devbox aktiv ist
# 2. Wartet auf GitHub Actions CI/CD Pipeline
# 3. Laedt das neue Image herunter
# 4. Loescht altes Template auf Proxmox
# 5. Erstellt neues Template
# 6. Deployed die VM mit Terraform
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DOWNLOAD_DIR="$HOME/Downloads/nixos-image"
REPO="kai-bruell/k3s-iac-homelab"
TEMPLATE_VM_ID="${TF_VAR_template_vm_id:-9001}"

# Farben fuer Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

# Benutzer-Bestaetigung
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        response="${response:-y}"
    else
        read -rp "$prompt [y/N]: " response
        response="${response:-n}"
    fi

    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# 1. Devbox-Check
# =============================================================================
check_devbox() {
    info "Pruefe Devbox-Umgebung..."

    if [[ -z "${DEVBOX_SHELL_ENABLED:-}" ]]; then
        error "Dieses Skript muss in einer Devbox-Shell ausgefuehrt werden!"
        echo ""
        echo "Starte Devbox mit:"
        echo "  cd $REPO_ROOT && devbox shell"
        echo ""
        exit 1
    fi

    # Pruefe ob .env geladen ist
    if [[ -z "${TF_VAR_proxmox_endpoint:-}" ]]; then
        error ".env wurde nicht geladen!"
        echo "Stelle sicher dass .env im Repository-Root existiert."
        exit 1
    fi

    success "Devbox aktiv, .env geladen"
}

# =============================================================================
# 2. Warten auf CI/CD Pipeline
# =============================================================================
wait_for_pipeline() {
    info "GitHub Actions Workflow Status:"
    echo ""

    # Zeige letzten Workflow-Run
    gh run list --repo "$REPO" --workflow "build-nixos-image.yml" --limit 3 || true

    echo ""
    warn "Warte auf CI/CD Pipeline..."
    echo "Oeffne GitHub Actions: https://github.com/$REPO/actions"
    echo ""

    while true; do
        if confirm "Ist die GitHub Actions Pipeline fertig?"; then
            break
        fi
        echo "Warte weiter..."
        sleep 5
    done

    success "Pipeline abgeschlossen"
}

# =============================================================================
# 3. Image herunterladen
# =============================================================================
download_image() {
    info "Lade NixOS Image herunter..."

    # Pruefe ob Verzeichnis existiert und Dateien enthaelt
    if [[ -d "$DOWNLOAD_DIR" ]] && [[ -n "$(ls -A "$DOWNLOAD_DIR" 2>/dev/null)" ]]; then
        warn "Verzeichnis $DOWNLOAD_DIR existiert bereits:"
        ls -la "$DOWNLOAD_DIR"
        echo ""
        if ! confirm "Vorhandene Dateien ueberschreiben?"; then
            error "Abgebrochen."
            exit 1
        fi
        rm -rf "$DOWNLOAD_DIR"
    fi

    mkdir -p "$DOWNLOAD_DIR"

    # GitHub Token aus gh CLI
    local TOKEN
    TOKEN="$(gh auth token)"

    # Neueste Artifact-ID holen
    local ARTIFACT_ID ARTIFACT_DATE
    ARTIFACT_ID=$(gh api "repos/$REPO/actions/artifacts" --jq '.artifacts[0].id')
    ARTIFACT_DATE=$(gh api "repos/$REPO/actions/artifacts" --jq '.artifacts[0].created_at')

    if [[ -z "$ARTIFACT_ID" ]]; then
        error "Keine Artifacts gefunden! Ist die Pipeline gelaufen?"
        exit 1
    fi

    info "Neuestes Artifact: ID $ARTIFACT_ID (erstellt: $ARTIFACT_DATE)"

    # Download
    curl -L -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO/actions/artifacts/$ARTIFACT_ID/zip" \
        -o "$DOWNLOAD_DIR/nixos.zip"

    # Entpacken
    unzip -o "$DOWNLOAD_DIR/nixos.zip" -d "$DOWNLOAD_DIR/"
    rm -f "$DOWNLOAD_DIR/nixos.zip"

    success "Download abgeschlossen:"
    ls -la "$DOWNLOAD_DIR"
}

# =============================================================================
# 4. Proxmox: Altes Template loeschen
# =============================================================================
delete_old_template() {
    info "Verbinde zu Proxmox..."

    # Proxmox Host aus Endpoint extrahieren
    local PROXMOX_HOST
    PROXMOX_HOST=$(echo "$TF_VAR_proxmox_endpoint" | sed -E 's|https?://([^:]+).*|\1|')

    info "Proxmox Host: $PROXMOX_HOST"

    # Pruefe ob Template existiert
    local TEMPLATE_EXISTS
    TEMPLATE_EXISTS=$(ssh "root@$PROXMOX_HOST" "qm status $TEMPLATE_VM_ID 2>/dev/null && echo 'exists' || echo 'not_found'")

    if [[ "$TEMPLATE_EXISTS" == *"exists"* ]]; then
        warn "Template VM $TEMPLATE_VM_ID existiert bereits."
        if confirm "Altes Template loeschen und ersetzen?"; then
            info "Loesche Template $TEMPLATE_VM_ID..."
            ssh "root@$PROXMOX_HOST" "qm destroy $TEMPLATE_VM_ID --purge"
            success "Template geloescht"
        else
            error "Abgebrochen. Template wird benoetigt."
            exit 1
        fi
    else
        info "Kein existierendes Template $TEMPLATE_VM_ID gefunden."
    fi
}

# =============================================================================
# 5. Proxmox: Neues Template erstellen
# =============================================================================
create_new_template() {
    info "Erstelle neues Template auf Proxmox..."

    local PROXMOX_HOST
    PROXMOX_HOST=$(echo "$TF_VAR_proxmox_endpoint" | sed -E 's|https?://([^:]+).*|\1|')

    # VMA-Datei finden
    local VMA_FILE
    VMA_FILE=$(find "$DOWNLOAD_DIR" -name "*.vma*" | head -1)

    if [[ -z "$VMA_FILE" ]]; then
        error "Keine VMA-Datei in $DOWNLOAD_DIR gefunden!"
        exit 1
    fi

    info "VMA-Datei: $VMA_FILE"

    # Upload zu Proxmox
    info "Lade Image auf Proxmox hoch..."
    scp "$VMA_FILE" "root@$PROXMOX_HOST:/var/lib/vz/dump/"

    # Template erstellen
    local VMA_FILENAME
    VMA_FILENAME=$(basename "$VMA_FILE")

    info "Erstelle VM aus VMA..."
    ssh "root@$PROXMOX_HOST" "qmrestore /var/lib/vz/dump/$VMA_FILENAME $TEMPLATE_VM_ID"

    info "Konvertiere zu Template..."
    ssh "root@$PROXMOX_HOST" "qm template $TEMPLATE_VM_ID"

    # Aufraeumen auf Proxmox
    info "Raeume temporaere Dateien auf..."
    ssh "root@$PROXMOX_HOST" "rm -f /var/lib/vz/dump/$VMA_FILENAME"

    success "Template $TEMPLATE_VM_ID erstellt"
}

# =============================================================================
# 6. Terraform: VM deployen
# =============================================================================
deploy_vm() {
    info "Deploye VM mit Terraform..."

    cd "$SCRIPT_DIR"

    # Pruefe ob VM existiert
    if tofu state list 2>/dev/null | grep -q "proxmox_virtual_environment_vm"; then
        warn "Existierende VM gefunden."
        if confirm "VM zerstoeren und neu erstellen?"; then
            info "Zerstoere alte VM..."
            tofu destroy -auto-approve
            success "VM zerstoert"
        else
            error "Abgebrochen."
            exit 1
        fi
    fi

    info "Erstelle neue VM..."
    tofu init -upgrade
    tofu apply -auto-approve

    success "VM deployed!"
    echo ""
    tofu output
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "=============================================="
    echo " NixOS Video-Editing VM - Deploy Pipeline"
    echo "=============================================="
    echo ""

    check_devbox
    echo ""

    wait_for_pipeline
    echo ""

    download_image
    echo ""

    delete_old_template
    echo ""

    create_new_template
    echo ""

    deploy_vm
    echo ""

    echo "=============================================="
    success "Deployment abgeschlossen!"
    echo "=============================================="
    echo ""
    echo "Naechste Schritte:"
    echo "  1. SSH: ssh user@<IP>"
    echo "  2. Sunshine: https://<IP>:47990"
    echo "  3. Moonlight verbinden"
    echo ""
}

main "$@"
