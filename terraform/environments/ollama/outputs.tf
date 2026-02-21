output "vm_id" {
  description = "Proxmox VM ID"
  value       = module.nixos_vm.vm_id
}

output "vm_name" {
  description = "VM Name"
  value       = module.nixos_vm.vm_name
}

output "vm_ip" {
  description = "IP-Adresse der VM"
  value       = module.nixos_vm.vm_ip
}

output "ssh_command" {
  description = "SSH-Verbindung zur VM"
  value       = module.nixos_vm.ssh_command
}
