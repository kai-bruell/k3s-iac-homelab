#!/bin/bash
set +e  # Don't exit on errors

echo "🧹 Cleaning up k3s-dev libvirt resources..."

# VMs - hardcoded names for reliability
echo "Destroying VMs..."
for vm in k3s-dev-server-1 k3s-dev-agent-1 k3s-dev-agent-2; do
  if virsh dominfo "$vm" &>/dev/null; then
    virsh destroy "$vm" 2>/dev/null && echo "  ✓ Destroyed $vm" || echo "  - $vm not running"
    virsh undefine "$vm" --remove-all-storage 2>/dev/null && echo "  ✓ Undefined $vm"
  else
    echo "  - $vm not found"
  fi
done

# Volumes
echo "Deleting volumes..."
virsh vol-list k3s-dev-pool 2>/dev/null | grep k3s-dev | awk '{print $1}' | while read vol; do
  [ -n "$vol" ] && virsh vol-delete "$vol" --pool k3s-dev-pool 2>/dev/null && echo "  ✓ Deleted volume $vol"
done

# Pool
echo "Removing pool..."
virsh pool-destroy k3s-dev-pool 2>/dev/null && echo "  ✓ Pool destroyed"
virsh pool-undefine k3s-dev-pool 2>/dev/null && echo "  ✓ Pool undefined"

# Storage directory
echo "Cleaning storage directory..."
sudo rm -rf /var/lib/libvirt/images/k3s-dev
sudo mkdir -p /var/lib/libvirt/images/k3s-dev
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/k3s-dev
sudo chmod 755 /var/lib/libvirt/images/k3s-dev
echo "  ✓ Directory cleaned and permissions set"

# Terraform state
echo "Removing Terraform state..."
rm -f terraform.tfstate terraform.tfstate.backup
echo "  ✓ State files removed"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Status:"
virsh list --all | grep -E "(Id|k3s-dev|^$)" || echo "  No VMs found"
virsh pool-list --all | grep -E "(Name|k3s-dev|^$)" || echo "  No pools found"
echo ""
echo "Ready for: terraform apply"
