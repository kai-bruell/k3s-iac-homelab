#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

NIX_SSHOPTS="-i ~/.ssh/homelab-dev" nixos-rebuild-ng switch \
  --flake "${REPO_ROOT}/nixos#videoediting" \
  --target-host root@192.168.178.181
