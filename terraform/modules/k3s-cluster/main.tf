terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
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

  cluster_name       = var.cluster_name
  vm_name            = "${var.cluster_name}-server-${count.index + 1}"
  pool_name          = var.pool_name
  base_volume_id     = var.base_volume_id
  butane_config_path = var.server_butane_config_path
  ssh_keys           = var.ssh_keys
  vcpu               = var.server_vcpu
  memory             = var.server_memory
  network_name       = var.network_name
  graphics_type      = var.graphics_type

  k3s_role       = "server"
  k3s_token      = local.k3s_token
  k3s_server_url = ""

  extra_butane_config = var.first_server_extra_config
}

# k3s Agent Nodes
module "k3s_agents" {
  source = "../flatcar-vm"
  count  = var.agent_count

  cluster_name       = var.cluster_name
  vm_name            = "${var.cluster_name}-agent-${count.index + 1}"
  pool_name          = var.pool_name
  base_volume_id     = var.base_volume_id
  butane_config_path = var.agent_butane_config_path
  ssh_keys           = var.ssh_keys
  vcpu               = var.agent_vcpu
  memory             = var.agent_memory
  network_name       = var.network_name
  graphics_type      = var.graphics_type

  k3s_role       = "agent"
  k3s_token      = local.k3s_token
  k3s_server_url = "https://${module.k3s_servers[0].vm_ip}:6443"

  extra_butane_config = var.agent_extra_config

  depends_on = [module.k3s_servers]
}
