terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password

  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = var.cluster_name

  # Proxmox
  node_name          = var.proxmox_node
  template_vm_id     = var.flatcar_template_id
  vm_id_start        = var.vm_id_start
  datastore_id       = var.datastore_id
  snippets_datastore = var.snippets_datastore
  network_bridge     = var.network_bridge

  # SSH
  ssh_keys = var.ssh_keys

  # Server Nodes
  server_count              = var.server_count
  server_vcpu               = var.server_vcpu
  server_memory             = var.server_memory
  server_disk_size          = var.server_disk_size
  server_butane_config_path = var.server_butane_config_path

  # Agent Nodes
  agent_count              = var.agent_count
  agent_vcpu               = var.agent_vcpu
  agent_memory             = var.agent_memory
  agent_disk_size          = var.agent_disk_size
  agent_butane_config_path = var.agent_butane_config_path

  # Netzwerk
  server_ips = var.server_ips
  agent_ips  = var.agent_ips
  gateway    = var.gateway
  dns        = var.dns

  # k3s Config
  k3s_token = var.k3s_token
}

# Automatisches Abrufen der kubeconfig
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [module.k3s_cluster]

  triggers = {
    server_ip = module.k3s_cluster.first_server_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Warte bis k3s bereit ist..."
      ssh-keygen -R ${module.k3s_cluster.first_server_ip} 2>/dev/null || true
      until ssh -i $HOME/.ssh/homelab-dev -o StrictHostKeyChecking=no -o ConnectTimeout=5 core@${module.k3s_cluster.first_server_ip} "test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; do
        sleep 5
      done
      echo "Lade kubeconfig herunter..."
      mkdir -p $HOME/.kube
      scp -i $HOME/.ssh/homelab-dev -o StrictHostKeyChecking=no core@${module.k3s_cluster.first_server_ip}:/etc/rancher/k3s/k3s.yaml $HOME/.kube/k3s-dev-config
      echo "Ersetze localhost mit Server-IP..."
      sed -i 's/127.0.0.1/${module.k3s_cluster.first_server_ip}/g' $HOME/.kube/k3s-dev-config
      chmod 600 $HOME/.kube/k3s-dev-config
      echo "✓ kubeconfig erfolgreich nach $HOME/.kube/k3s-dev-config heruntergeladen!"
    EOT
  }
}

# FluxCD Bootstrap
resource "null_resource" "flux_bootstrap" {
  depends_on = [null_resource.fetch_kubeconfig]

  triggers = {
    server_ip = module.k3s_cluster.first_server_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG=$HOME/.kube/k3s-dev-config
      echo "Warte bis Nodes ready sind..."
      for i in $(seq 1 60); do
        if kubectl get nodes 2>/dev/null | grep -q " Ready"; then
          echo "Nodes gefunden, warte auf alle..."
          sleep 10
          kubectl get nodes
          break
        fi
        echo "Warte auf Nodes... ($i/60)"
        sleep 5
      done
      echo "Bootstrap FluxCD..."
      flux bootstrap github \
        --owner=${var.github_owner} \
        --repository=${var.github_repository} \
        --branch=${var.github_branch} \
        --path=./kubernetes \
        --personal
      echo "✓ FluxCD erfolgreich gebootstrapped!"
    EOT
  }
}
