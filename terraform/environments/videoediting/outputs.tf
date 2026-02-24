output "vm_id" {
  description = "Proxmox VM ID"
  value       = module.nixos_vm.vm_id
}

output "vm_name" {
  description = "VM Name in Proxmox"
  value       = module.nixos_vm.vm_name
}

output "bootstrap_ip" {
  description = "Temporaere DHCP-IP (Bootstrap-Phase, danach statische IP aus Flake aktiv)"
  value       = module.nixos_vm.bootstrap_ip
}

output "ssh_hint" {
  description = "SSH-Verbindung nach Deploy (IP in nixos/hosts/videoediting/default.nix einsehen)"
  value       = module.nixos_vm.ssh_hint
}
