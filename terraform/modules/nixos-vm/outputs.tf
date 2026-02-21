output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "VM Name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "vm_ip" {
  description = "Statische IP-Adresse der VM (nach nixos-rebuild)"
  value       = local.static_ip
}

output "ssh_command" {
  description = "SSH-Verbindungsbefehl"
  value       = "ssh -i ${var.ssh_private_key_path} root@${local.static_ip}"
}
