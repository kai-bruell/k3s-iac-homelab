output "k3s_token" {
  description = "k3s Cluster Token"
  value       = local.k3s_token
  sensitive   = true
}

output "server_ips" {
  description = "IP-Adressen der k3s Server Nodes"
  value       = [for server in module.k3s_servers : server.vm_ip]
}

output "agent_ips" {
  description = "IP-Adressen der k3s Agent Nodes"
  value       = [for agent in module.k3s_agents : agent.vm_ip]
}

output "first_server_ip" {
  description = "IP des ersten Server Nodes (für kubeconfig)"
  value       = module.k3s_servers[0].vm_ip
}

output "k3s_server_url" {
  description = "k3s API Server URL"
  value       = "https://${module.k3s_servers[0].vm_ip}:6443"
}
