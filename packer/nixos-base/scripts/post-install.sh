#!/usr/bin/env bash
set -euo pipefail

echo "=== Template Cleanup ==="

# SSH Host Keys loeschen damit jeder Clone eigene Keys generiert.
# Ohne das haetten alle VMs aus diesem Template dieselben Host Keys
# -> SSH wuerde bei Verbindung zu einer anderen VM warnen.
# WICHTIG: /mnt-Prefix weil dieses Script von der Live-ISO laeuft,
# nicht vom installierten System.
echo "--- SSH Host Keys loeschen ---"
rm -f /mnt/etc/ssh/ssh_host_*

echo "=== Template Cleanup abgeschlossen ==="
