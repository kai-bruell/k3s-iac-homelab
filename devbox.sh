#!/bin/bash

# Devbox initialization script
# This runs when entering the devbox shell

# Load .env if exists
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "Devbox environment loaded"

# Show loaded config (without secrets)
if [ -n "$TF_VAR_proxmox_endpoint" ]; then
  HOST=$(echo "$TF_VAR_proxmox_endpoint" | sed -E 's|https?://([^:]+).*|\1|')
  echo "Proxmox: ${TF_VAR_proxmox_username}@${HOST}"
fi
