#!/bin/bash
set -euo pipefail

# Extract host and user from TF_VAR_ environment variables
PROXMOX_HOST=$(echo "$TF_VAR_proxmox_endpoint" | sed -E 's|https?://([^:]+).*|\1|')
PROXMOX_USER=$(echo "$TF_VAR_proxmox_username" | sed 's/@.*//')
TEMPLATE_ID="${TF_VAR_flatcar_template_id:-9000}"
PROXMOX_NODE="${TF_VAR_proxmox_node}"

# Flatcar settings
FLATCAR_CHANNEL="stable"
FLATCAR_VERSION="current"
STORAGE="${TF_VAR_datastore_id:-local-lvm}"

echo "=== Flatcar Template Setup ==="
echo "Proxmox: ${PROXMOX_USER}@${PROXMOX_HOST}"
echo "Node: ${PROXMOX_NODE}"
echo "Template ID: ${TEMPLATE_ID}"
echo ""

# Commands to run on Proxmox
REMOTE_SCRIPT=$(cat <<'SCRIPT'
set -euo pipefail

TEMPLATE_ID="__TEMPLATE_ID__"
NODE="__NODE__"
STORAGE="__STORAGE__"
CHANNEL="__CHANNEL__"
VERSION="__VERSION__"

FLATCAR_URL="https://${CHANNEL}.release.flatcar-linux.net/amd64-usr/${VERSION}/flatcar_production_qemu_image.img"
WORK_DIR="/tmp"
IMAGE_PATH="${WORK_DIR}/flatcar_production_qemu_image.img"

# Ensure snippets directory exists and storage supports snippets
mkdir -p /var/lib/vz/snippets
pvesm set local --content backup,iso,vztmpl,snippets 2>/dev/null || true

# Check if template already exists
if qm status "$TEMPLATE_ID" &>/dev/null; then
  echo ">>> Template $TEMPLATE_ID already exists!"
  echo ">>> Delete it first with: qm destroy $TEMPLATE_ID"
  exit 1
fi

# Check if image already exists (manually uploaded)
if [ -f "$IMAGE_PATH" ]; then
  echo ">>> Image already exists at $IMAGE_PATH, skipping download"
else
  echo ">>> Downloading Flatcar image..."
  wget -q --show-progress -O "$IMAGE_PATH" "$FLATCAR_URL"
fi

echo ">>> Creating VM $TEMPLATE_ID..."
qm create "$TEMPLATE_ID" \
  --name flatcar-template \
  --cores 2 \
  --memory 2048 \
  --net0 virtio,bridge=vmbr0 \
  --serial0 socket \
  --vga serial0 \
  --ostype l26

echo ">>> Importing disk to $STORAGE..."
qm importdisk "$TEMPLATE_ID" "$IMAGE_PATH" "$STORAGE"

echo ">>> Configuring VM..."
qm set "$TEMPLATE_ID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${TEMPLATE_ID}-disk-0"
qm set "$TEMPLATE_ID" --boot order=scsi0

echo ">>> Converting to template..."
qm template "$TEMPLATE_ID"

echo ">>> Cleaning up..."
rm -f "$IMAGE_PATH"

echo ""
echo "=== Template created successfully! ==="
echo "Template ID: $TEMPLATE_ID"
echo "Name: flatcar-template"
SCRIPT
)

# Replace placeholders
REMOTE_SCRIPT="${REMOTE_SCRIPT//__TEMPLATE_ID__/$TEMPLATE_ID}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__NODE__/$PROXMOX_NODE}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__STORAGE__/$STORAGE}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__CHANNEL__/$FLATCAR_CHANNEL}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__VERSION__/$FLATCAR_VERSION}"

echo ">>> Connecting to Proxmox..."
ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "$REMOTE_SCRIPT"
