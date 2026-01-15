terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Generiere k3s Token falls nicht angegeben
resource "random_password" "k3s_token" {
  count   = var.k3s_token == "" ? 1 : 0
  length  = 48
  special = false
}

locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result
}

# k3s Server Nodes
module "k3s_servers" {
  source = "../flatcar-vm"
  count  = var.server_count

  # Proxmox
  node_name          = var.node_name
  vm_id              = var.vm_id_start + count.index
  template_vm_id     = var.template_vm_id
  datastore_id       = var.datastore_id
  snippets_datastore = var.snippets_datastore
  network_bridge     = var.network_bridge

  # VM
  vm_name  = "${var.cluster_name}-server-${count.index + 1}"
  vcpu     = var.server_vcpu
  memory   = var.server_memory
  disk_size = var.server_disk_size

  # Butane/Ignition
  butane_config_path  = var.server_butane_config_path
  ssh_keys            = var.ssh_keys
  extra_butane_config = var.first_server_extra_config

  # Netzwerk
  static_ip = var.server_ips[count.index]
  gateway   = var.gateway
  dns       = var.dns

  # k3s
  k3s_role       = "server"
  k3s_token      = local.k3s_token
  k3s_server_url = ""
}

# k3s Agent Nodes
module "k3s_agents" {
  source = "../flatcar-vm"
  count  = var.agent_count

  # Proxmox
  node_name          = var.node_name
  vm_id              = var.vm_id_start + var.server_count + count.index
  template_vm_id     = var.template_vm_id
  datastore_id       = var.datastore_id
  snippets_datastore = var.snippets_datastore
  network_bridge     = var.network_bridge

  # VM
  vm_name   = "${var.cluster_name}-agent-${count.index + 1}"
  vcpu      = var.agent_vcpu
  memory    = var.agent_memory
  disk_size = var.agent_disk_size

  # Butane/Ignition
  butane_config_path  = var.agent_butane_config_path
  ssh_keys            = var.ssh_keys
  extra_butane_config = var.agent_extra_config

  # Netzwerk
  static_ip = var.agent_ips[count.index]
  gateway   = var.gateway
  dns       = var.dns

  # k3s
  k3s_role       = "agent"
  k3s_token      = local.k3s_token
  k3s_server_url = "https://${module.k3s_servers[0].vm_ip}:6443"

  depends_on = [module.k3s_servers]
}
