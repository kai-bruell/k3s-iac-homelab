#!/bin/bash

# Devbox initialization script
# This runs when entering the devbox shell

# TODO: Add dependency checks
# - Check if libvirtd is running (systemctl status libvirtd)
# - Check if user is in libvirt group (groups | grep libvirt)
# - Check if default network exists (virsh net-list --all)
# - Verify socket is accessible (test -S /var/run/libvirt/libvirt-sock)

# TODO: Add helpful environment setup
# - Set LIBVIRT_DEFAULT_URI if needed
# - Print status message with virsh connection info
# - Show running VMs

echo "Devbox environment loaded"
echo "Using system libvirtd (qemu:///system)"
