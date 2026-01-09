output "vm_id" {
  description = "ID der VM"
  value       = libvirt_domain.vm.id
}

output "vm_name" {
  description = "Name der VM"
  value       = libvirt_domain.vm.name
}

output "vm_ip" {
  description = "IP-Adresse der VM"
  value       = try(libvirt_domain.vm.network_interface[0].addresses[0], "")
}
