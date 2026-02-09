#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
NIXOS_DIR="${SCRIPT_DIR}/nixos"
REMOTE_DIR="/etc/nixos"

# --- .env laden ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Fehler: ${ENV_FILE} nicht gefunden."
  echo "Erstelle eine .env basierend auf .env.example"
  exit 1
fi

eval "$(sed "s/[[:space:]]*=[[:space:]]*/=/" "$ENV_FILE" | sed "s/'//g")"

if [[ -z "${VM_HOST:-}" || -z "${VM_USER:-}" ]]; then
  echo "Fehler: VM_HOST und VM_USER muessen in .env gesetzt sein."
  exit 1
fi

# SMB-Variablen pruefen
if [[ -z "${SMB_SERVER:-}" || -z "${SMB_MOUNT_POINT:-}" || -z "${SMB_USERNAME:-}" || -z "${SMB_PASSWORD:-}" ]]; then
  echo "Fehler: SMB_SERVER, SMB_MOUNT_POINT, SMB_USERNAME und SMB_PASSWORD muessen in .env gesetzt sein."
  exit 1
fi
SMB_DOMAIN="${SMB_DOMAIN:-WORKGROUP}"

# --- smb-mount.nix aus .env generieren ---
cat > "${NIXOS_DIR}/smb-mount.nix" <<NIXEOF
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  fileSystems."${SMB_MOUNT_POINT}" = {
    device = "${SMB_SERVER}";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["\${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100,noperm"];
  };
}
NIXEOF
echo "smb-mount.nix aus .env generiert."

# SSH ControlMaster: SSH-Passwort nur einmal eingeben
SOCKET="/tmp/ssh-deploy-${VM_USER}-${VM_HOST}"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=${SOCKET} -o ControlPersist=300"

cleanup() {
  ssh -o ControlPath="${SOCKET}" -O exit "${VM_USER}@${VM_HOST}" 2>/dev/null || true
}
trap cleanup EXIT

# --- Hilfsfunktionen ---
frage() {
  local prompt="$1"
  while true; do
    read -rp "${prompt} [j/n]: " antwort
    case "$antwort" in
      [jJ]) return 0 ;;
      [nN]) return 1 ;;
      *) echo "Bitte j oder n eingeben." ;;
    esac
  done
}

remote() {
  ssh -t ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "$@"
}

upload() {
  scp ${SSH_OPTS} "$1" "${VM_USER}@${VM_HOST}:$2"
}

# --- SSH Verbindung testen ---
echo "Teste SSH-Verbindung zu ${VM_USER}@${VM_HOST}..."
if ! remote "echo ok"; then
  echo "Fehler: SSH-Verbindung fehlgeschlagen."
  exit 1
fi
echo "Verbindung erfolgreich."
echo ""

# --- Vorhandene Dateien auf dem Server anzeigen ---
echo "Aktuelle Dateien auf dem Server in ${REMOTE_DIR}:"
remote "ls -la ${REMOTE_DIR}/" 2>/dev/null || echo "(Verzeichnis existiert nicht)"
echo ""

# --- Lokale Dateien anzeigen ---
echo "Lokale NixOS-Dateien die hochgeladen werden:"
for f in "${NIXOS_DIR}"/*.nix; do
  echo "  $(basename "$f")"
done
echo ""

# --- Beide Fragen vorher stellen ---
DO_UPLOAD=false
DO_REBUILD=false

if frage "Sollen die Dateien nach ${REMOTE_DIR}/ hochgeladen (und ggf. ueberschrieben) werden?"; then
  DO_UPLOAD=true
  if frage "Soll danach 'sudo nixos-rebuild switch' ausgefuehrt werden?"; then
    DO_REBUILD=true
  fi
else
  echo "Abgebrochen."
  exit 0
fi

# --- Dateien nach /tmp hochladen (kein sudo noetig) ---
echo ""
for f in "${NIXOS_DIR}"/*.nix; do
  fname="$(basename "$f")"
  echo "Lade hoch: ${fname} -> /tmp/${fname}"
  upload "$f" "/tmp/${fname}"
done

# --- Alles in einer einzigen SSH-Session mit sudo ausfuehren ---
REMOTE_SCRIPT="sudo -v"
for f in "${NIXOS_DIR}"/*.nix; do
  fname="$(basename "$f")"
  REMOTE_SCRIPT="${REMOTE_SCRIPT} && sudo cp /tmp/${fname} ${REMOTE_DIR}/${fname} && rm /tmp/${fname}"
done

# smb-secrets auf der VM erstellen
REMOTE_SCRIPT="${REMOTE_SCRIPT} && echo -e 'username=${SMB_USERNAME}\npassword=${SMB_PASSWORD}\ndomain=${SMB_DOMAIN}' | sudo tee ${REMOTE_DIR}/smb-secrets > /dev/null && sudo chmod 600 ${REMOTE_DIR}/smb-secrets"
REMOTE_SCRIPT="${REMOTE_SCRIPT} && echo smb-secrets erstellt."

REMOTE_SCRIPT="${REMOTE_SCRIPT} && echo && echo Dateien auf dem Server: && ls -la ${REMOTE_DIR}/*.nix ${REMOTE_DIR}/smb-secrets"

if [[ "$DO_REBUILD" == true ]]; then
  REMOTE_SCRIPT="${REMOTE_SCRIPT} && echo && echo Starte nixos-rebuild switch... && echo ========================================= && sudo nixos-rebuild switch && echo ========================================= && echo NixOS Rebuild abgeschlossen."
fi

echo ""
echo "Fuehre sudo-Operationen auf dem Server aus..."
remote "${REMOTE_SCRIPT}"

echo ""
echo "Fertig."
