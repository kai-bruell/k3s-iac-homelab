output "vm_id" {
  description = "ID der VM in Proxmox"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "Name der VM"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "vm_ip" {
  description = "IP-Adresse der VM"
  value       = split("/", var.static_ip)[0]
}
