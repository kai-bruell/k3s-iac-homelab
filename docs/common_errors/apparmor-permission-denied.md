# AppArmor Permission Denied Error

## Error Symptom

When running `terraform apply`, VMs fail to start with:

```
Error: error creating libvirt domain: internal error: process exited while connecting to monitor:
qemu-system-x86_64: -blockdev {"driver":"file","filename":"/var/lib/libvirt/images/k3s-dev/k3s-dev-base.img",...}:
Could not open '/var/lib/libvirt/images/k3s-dev/k3s-dev-base.img': Permission denied
```

## Root Cause Analysis

This is a **complex interaction** between libvirt, QEMU, AppArmor, and Terraform:

### The Problem Chain

1. **Terraform creates disk images** with ownership `root:root`
2. **libvirt's `virt-aa-helper`** runs to generate AppArmor profiles for the VM
3. **`virt-aa-helper` tries to read the disk images** to detect backing file chains (for qcow2 images)
4. **AppArmor blocks `virt-aa-helper`** from reading files owned by `root:root` in custom storage pools
5. **`virt-aa-helper` fails to detect backing files** → disk paths are NOT added to AppArmor profile
6. **VM starts** → QEMU process is blocked by AppArmor from accessing the disks
7. **Permission denied error**

### Related Bugs

- **Ubuntu Bug #1704782**: "qcow base image apparmor rule missing in artful"
  - Fixed in libvirt 3.5.0 (July 2017)
  - However, the fix requires `virt-aa-helper` to successfully read disk images
  - If AppArmor blocks `virt-aa-helper` itself, the fix cannot work

### Why This Happens with Custom Storage Pools

- Default storage pool: `/var/lib/libvirt/images/`
- Custom storage pool: `/var/lib/libvirt/images/k3s-dev/`

The AppArmor profile for `virt-aa-helper` includes:
```
/var/lib/libvirt/images/** r,
```

This **should** match custom subdirectories, but in practice, there are edge cases where:
- File ownership conflicts with read permissions
- Backing file chains in custom pools are not properly detected
- Race conditions between `dynamic_ownership` and `virt-aa-helper` execution

## Solution

### Step 1: Configure qemu.conf

Ensure `/etc/libvirt/qemu.conf` has:

```conf
# Enable dynamic ownership (libvirt automatically changes file ownership when VMs start)
dynamic_ownership = 1

# DO NOT set user = "root" - let QEMU run as unprivileged user
# user = "root"   # ← Keep this commented out!
# group = "root"  # ← Keep this commented out!
```

**Why?**
- Running QEMU as root is a security risk (privilege escalation if VM escapes)
- `dynamic_ownership = 1` automatically changes disk file ownership to `libvirt-qemu:kvm` when VMs start
- This follows the principle of least privilege

### Step 2: Add Custom AppArmor Rule

Create or append to `/etc/apparmor.d/local/abstractions/libvirt-qemu`:

```
# Custom storage pool for k3s-dev cluster
# Allow QEMU to access disk images in custom storage pools
/var/lib/libvirt/images/k3s-dev/** rwk,
```

**Adjust the path** if your storage pool is in a different location:
```
/var/lib/libvirt/images/<your-cluster-name>/** rwk,
```

### Step 3: Reload AppArmor

```bash
sudo systemctl reload apparmor
```

### Step 4: Restart libvirtd

```bash
sudo systemctl restart libvirtd
```

### Step 5: Test with Terraform

```bash
cd homelab-iac/terraform/environments/development
terraform apply
```

## Verification

After applying the fix, check:

1. **AppArmor logs** - no more "DENIED" entries:
```bash
sudo journalctl --since "5 minutes ago" | grep "apparmor.*DENIED"
```

2. **VM disk file ownership** - should be `libvirt-qemu:kvm` when VM is running:
```bash
sudo ls -lah /var/lib/libvirt/images/k3s-dev/
```

3. **AppArmor profile for VM** includes disk paths:
```bash
sudo cat /etc/apparmor.d/libvirt/libvirt-*.files | grep "k3s-dev"
```

## Platform Specificity

This issue **only affects** distributions using **AppArmor**:
- ✓ Ubuntu / Debian
- ✓ openSUSE

**Does NOT affect** distributions using **SELinux**:
- Fedora / RHEL / CentOS
- SELinux automatically labels disk images correctly (`virt_image_t`)
- SELinux handles backing files better than AppArmor

**Does NOT affect** distributions without MAC (Mandatory Access Control):
- Arch Linux (unless AppArmor is manually enabled)
- Gentoo (unless SELinux/AppArmor is manually enabled)

## Automation for Reproducible Setup

To make this fix reproducible across different hosts, add a setup script:

```bash
#!/bin/bash
# setup-apparmor.sh

CLUSTER_NAME="${1:-k3s-dev}"
STORAGE_PATH="/var/lib/libvirt/images/${CLUSTER_NAME}"

# Check if AppArmor is active
if [ -d /etc/apparmor.d/local/abstractions ]; then
  echo "Configuring AppArmor for libvirt custom storage pool..."

  # Add custom pool to AppArmor profile
  echo "# Custom libvirt pool for ${CLUSTER_NAME}" | sudo tee -a /etc/apparmor.d/local/abstractions/libvirt-qemu
  echo "${STORAGE_PATH}/** rwk," | sudo tee -a /etc/apparmor.d/local/abstractions/libvirt-qemu

  # Reload AppArmor
  sudo systemctl reload apparmor
  echo "✓ AppArmor configured"
else
  echo "AppArmor not detected, skipping configuration"
fi

# Check qemu.conf settings
if grep -q "^user = \"root\"" /etc/libvirt/qemu.conf; then
  echo "⚠ WARNING: qemu.conf has 'user = root' - consider removing for better security"
fi

if ! grep -q "^dynamic_ownership = 1" /etc/libvirt/qemu.conf; then
  echo "⚠ WARNING: dynamic_ownership is not enabled in /etc/libvirt/qemu.conf"
fi
```

Usage:
```bash
chmod +x setup-apparmor.sh
./setup-apparmor.sh k3s-dev
```

## References

- Ubuntu Bug #1704782: https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1704782
- libvirt Security with AppArmor: https://libvirt.org/drvqemu.html#security-apparmor
- libvirt Storage Pools: https://libvirt.org/storage.html
