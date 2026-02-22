#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building devbox container image ==="
podman build -t devbox:latest "$SCRIPT_DIR"

echo "=== Creating distrobox ==="
distrobox assemble create --file "$SCRIPT_DIR/distrobox.ini"

echo "=== Done! ==="
echo "Enter with: distrobox enter devbox"
