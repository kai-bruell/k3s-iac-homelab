terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

locals {
  static_ip    = split("/", var.static_ip)[0]
  prefix_length = split("/", var.static_ip)[1]

  host_params_content = templatefile("${path.module}/templates/host-params.nix.tftpl", {
    hostname          = var.hostname
    ip_address        = local.static_ip
    prefix_length     = local.prefix_length
    gateway           = var.gateway
    dns               = var.dns
    ssh_keys          = var.ssh_keys
    network_interface = var.network_interface
  })
}

# --- VM klonen und konfigurieren ---

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  bios    = "ovmf"
  machine = "q35"

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores   = var.vcpu
    sockets = var.sockets
    type    = "host"
    numa    = var.numa_enabled
  }

  memory {
    dedicated = var.memory
  }

  # NUMA Topologie (nur wenn aktiviert)
  dynamic "numa" {
    for_each = var.numa_enabled ? [1] : []
    content {
      device    = "numa0"
      cpus      = "0-${var.vcpu - 1}"
      memory    = var.memory
      hostnodes = "0"
      policy    = "preferred"
    }
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }

  network_device {
    bridge = var.network_bridge
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }
}

# --- Flake + host-params.nix deployen und nixos-rebuild ausfuehren ---

resource "null_resource" "deploy_nixos" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  triggers = {
    flake_hash = sha256(join("", [
      for f in fileset(var.nixos_flake_dir, "**") :
      filesha256("${var.nixos_flake_dir}/${f}")
    ]))
    host_params = sha256(local.host_params_content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # --- 1. DHCP-IP per Guest Agent vom Proxmox-Host abfragen ---
      echo "Frage VM-IP vom Proxmox Guest Agent ab..."
      VM_IP=""
      for i in $(seq 1 60); do
        VM_IP=$(ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
          root@${var.proxmox_ssh_host} \
          "qm guest cmd ${var.vm_id} network-get-interfaces" 2>/dev/null | \
          python3 -c "
import sys, json
data = json.load(sys.stdin)
for iface in data:
    if iface.get('name') == 'lo': continue
    for addr in iface.get('ip-addresses', []):
        if addr.get('ip-address-type') == 'ipv4':
            print(addr['ip-address'])
            sys.exit(0)
" 2>/dev/null) || true

        if [ -n "$VM_IP" ]; then
          echo "VM-IP gefunden: $VM_IP"
          break
        fi
        echo "Versuch $i/60 - Guest Agent meldet noch keine IP..."
        sleep 5
      done

      if [ -z "$VM_IP" ]; then
        echo "FEHLER: Keine IP vom Guest Agent nach 5 Minuten"
        exit 1
      fi

      # --- 2. SSH auf DHCP-IP warten ---
      echo "Warte auf SSH-Verbindung zu $VM_IP..."
      ssh-keygen -R "$VM_IP" 2>/dev/null || true
      for i in $(seq 1 60); do
        if ssh -i ${var.ssh_private_key_path} \
               -o StrictHostKeyChecking=no \
               -o ConnectTimeout=5 \
               -o BatchMode=yes \
               root@"$VM_IP" "echo ok" 2>/dev/null; then
          echo "SSH-Verbindung zu $VM_IP erfolgreich!"
          break
        fi
        echo "Versuch $i/60 - SSH noch nicht bereit..."
        sleep 5
      done

      # --- 3. Flake + host-params.nix hochladen ---
      echo "Erstelle Flake-Archiv..."
      TMPDIR=$(mktemp -d /tmp/nixos-deploy-XXXXXX)
      cp -r ${var.nixos_flake_dir}/. "$TMPDIR/"
      cat > "$TMPDIR/host-params.nix" << 'HOSTPARAMS'
      ${local.host_params_content}
      HOSTPARAMS

      ARCHIVE=$(mktemp /tmp/nixos-flake-XXXXXX.tar.gz)
      tar -czf "$ARCHIVE" -C "$TMPDIR" .

      echo "Lade Flake hoch nach $VM_IP:/etc/nixos/..."
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          root@"$VM_IP" "rm -rf /etc/nixos/* && mkdir -p /etc/nixos"
      scp -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          "$ARCHIVE" root@"$VM_IP":/tmp/nixos-flake.tar.gz
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          root@"$VM_IP" "tar -xzf /tmp/nixos-flake.tar.gz -C /etc/nixos/ && rm /tmp/nixos-flake.tar.gz"

      rm -rf "$TMPDIR" "$ARCHIVE"
      echo "Flake erfolgreich hochgeladen!"

      # --- 4. Git init (Nix Flakes braucht Git) ---
      echo "Initialisiere Git-Repo in /etc/nixos/..."
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          root@"$VM_IP" \
          "git config --global --add safe.directory /etc/nixos && git config --global user.email 'nix@localhost' && git config --global user.name 'NixOS' && cd /etc/nixos && git init && git add -A && git commit -m 'nixos flake deploy' --allow-empty"
      echo "Git-Repo initialisiert!"

      # --- 5. nixos-rebuild switch (IP-Wechsel bricht SSH ab) ---
      echo "Starte nixos-rebuild switch auf $VM_IP..."
      echo "HINWEIS: IP wechselt von $VM_IP (DHCP) auf ${local.static_ip} (statisch)"
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          root@"$VM_IP" \
          "nohup nixos-rebuild switch --flake /etc/nixos#${var.nixos_flake_target} > /tmp/nixos-rebuild.log 2>&1 &"

      echo "Warte 30s bis nixos-rebuild laeuft..."
      sleep 30

      # --- 6. SSH auf statischer IP warten ---
      echo "Warte auf SSH unter ${local.static_ip}..."
      ssh-keygen -R ${local.static_ip} 2>/dev/null || true
      for i in $(seq 1 60); do
        if ssh -i ${var.ssh_private_key_path} \
               -o StrictHostKeyChecking=no \
               -o ConnectTimeout=5 \
               -o BatchMode=yes \
               root@${local.static_ip} "echo ok" 2>/dev/null; then
          echo "nixos-rebuild abgeschlossen! VM erreichbar unter ${local.static_ip}"
          exit 0
        fi
        echo "Versuch $i/60 - Warte auf ${local.static_ip}..."
        sleep 10
      done
      echo "FEHLER: VM nach nixos-rebuild nicht unter ${local.static_ip} erreichbar"
      exit 1
    EOT
    environment = {
      SSH_AUTH_SOCK = ""
    }
  }
}
