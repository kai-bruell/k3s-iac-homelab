output "k3s_token" {
  description = "k3s Cluster Token"
  value       = module.k3s_cluster.k3s_token
  sensitive   = true
}

output "server_ips" {
  description = "IP-Adressen der k3s Server Nodes"
  value       = module.k3s_cluster.server_ips
}

output "agent_ips" {
  description = "IP-Adressen der k3s Agent Nodes"
  value       = module.k3s_cluster.agent_ips
}

output "k3s_server_url" {
  description = "k3s API Server URL"
  value       = module.k3s_cluster.k3s_server_url
}

output "ssh_command" {
  description = "SSH-Verbindung zum k3s Server"
  value       = "ssh -i ~/.ssh/homelab-dev core@${module.k3s_cluster.first_server_ip}"
}

output "kubeconfig_setup" {
  description = "Kubeconfig aktivieren"
  value       = "export KUBECONFIG=~/.kube/k3s-dev-config"
}
