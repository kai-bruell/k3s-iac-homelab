#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

echo "=== Building NixOS Image for Proxmox ==="
nixos-generate \
  -f proxmox \
  -c "$SCRIPT_DIR/nixos/configuration.nix" \
  -o "$OUTPUT_DIR/nixos-video-editing"

echo ""
echo "=== Image erstellt ==="
echo "Output: $OUTPUT_DIR/nixos-video-editing"
echo ""
echo "Naechste Schritte:"
echo "  1. Image auf Proxmox hochladen:"
echo "     scp $OUTPUT_DIR/nixos-video-editing/*.vma* root@proxmox:/var/lib/vz/dump/"
echo "  2. Template erstellen:"
echo "     qmrestore /var/lib/vz/dump/nixos-*.vma 9001"
echo "     qm template 9001"
echo "  3. Terraform ausfuehren:"
echo "     tofu apply"
