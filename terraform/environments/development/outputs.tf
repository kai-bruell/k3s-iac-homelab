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

output "kubeconfig_command" {
  description = "Befehl zum Abrufen der kubeconfig"
  value       = "scp core@${module.k3s_cluster.first_server_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev-config"
}
