terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# Storage Pool für den gesamten Cluster
resource "libvirt_pool" "cluster_pool" {
  name = "${var.cluster_name}-pool"
  type = "dir"
  path = var.pool_path
}

# Basis-Image für alle VMs im Cluster
resource "libvirt_volume" "base_image" {
  name   = "${var.cluster_name}-base.img"
  source = var.base_image_path
  pool   = libvirt_pool.cluster_pool.name
  format = "qcow2"
}

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name   = var.cluster_name
  pool_name      = libvirt_pool.cluster_pool.name
  base_volume_id = libvirt_volume.base_image.id
  ssh_keys       = var.ssh_keys

  # Server Nodes
  server_count              = var.server_count
  server_vcpu               = var.server_vcpu
  server_memory             = var.server_memory
  server_butane_config_path = var.server_butane_config_path

  # Agent Nodes
  agent_count              = var.agent_count
  agent_vcpu               = var.agent_vcpu
  agent_memory             = var.agent_memory
  agent_butane_config_path = var.agent_butane_config_path

  # Netzwerk
  network_name  = var.network_name
  graphics_type = var.graphics_type

  # k3s Config
  k3s_token = var.k3s_token
}
