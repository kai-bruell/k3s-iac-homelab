output "vm_id" {
  description = "VM ID in Proxmox"
  value       = proxmox_virtual_environment_vm.video_editing.vm_id
}

output "vm_name" {
  description = "VM Name"
  value       = proxmox_virtual_environment_vm.video_editing.name
}

output "mac_address" {
  description = "MAC Adresse der VM (fuer DHCP Reservation)"
  value       = proxmox_virtual_environment_vm.video_editing.network_device[0].mac_address
}

output "ip_address" {
  description = "IP Adresse der VM"
  value       = proxmox_virtual_environment_vm.video_editing.ipv4_addresses[1][0]
}

output "ssh_connection" {
  description = "SSH Befehl zum Verbinden"
  value       = "ssh user@${proxmox_virtual_environment_vm.video_editing.ipv4_addresses[1][0]}"
}

output "sunshine_url" {
  description = "Sunshine Web UI URL"
  value       = "https://${proxmox_virtual_environment_vm.video_editing.ipv4_addresses[1][0]}:47990"
}
