output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "VM Name in Proxmox"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "bootstrap_ip" {
  description = "Temporaere DHCP-IP der Bootstrap-VM (Debian, nur waehrend nixos-anywhere Deploy aktiv)"
  value       = local.vm_ip
}

output "ssh_hint" {
  description = "SSH-Verbindung nach erfolgreichem Deploy (IP aus nixos/hosts/<host>/default.nix)"
  value       = "ssh -i ${var.ssh_private_key_path} root@<static-ip-aus-flake>"
}
