# Proxmox GPU Passthrough Guide

**Author:** Matt Olan
**Published:** June 28, 2021
**Last Modified:** July 25, 2025
**Source:** <https://matt.olan.me/post/proxmox-gpu-passthrough-guide/>

---

## Introduction

Rather than purchasing new hardware during a chip shortage, GPU passthrough using Proxmox Virtual Environment allows sharing existing resources between multiple virtual machines for additional computing power (e.g. multiplayer gaming).

---

## Host Configuration

### IOMMU

Input-output memory management unit (IOMMU) is a hardware feature that can perform the mapping from guest-physical addresses to host-physical addresses. This feature must be enabled in BIOS:

- **AMD CPUs:** Enable AMD-Vi
- **Intel CPUs:** Enable VT-d

Then configure the Linux kernel via GRUB parameters in `/etc/default/grub`:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on pcie_acs_override=downstream,multifunction video=efifb:off"
```

| Parameter | Purpose |
|---|---|
| `amd_iommu=on` | Enables IOMMU for AMD CPUs (use `intel_iommu=on` for Intel) |
| `pcie_acs_override=downstream,multifunction` | Enables granular PCIe device passthrough |
| `video=efifb:off` | Resolves BAR reservation issues |

### Drivers

Graphics drivers must be blacklisted on the host. Edit `/etc/modprobe.d/blacklist.conf`:

```bash
blacklist radeon
blacklist nouveau
blacklist nvidia
```

### VFIO

Virtual Function I/O (VFIO) configuration requires enabling kernel modules. Edit `/etc/modules`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

#### PCI Device Identification

Use `lspci` to identify GPU devices:

```
05:00.0 VGA compatible controller: NVIDIA Corporation GK104 [GeForce GTX 760] (rev a1)
05:00.1 Audio device: NVIDIA Corporation GK104 HDMI Audio Controller (rev a1)
0b:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Fiji [Radeon R9 FURY / NANO Series] (rev c8)
0b:00.1 Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Fiji HDMI/DP Audio [Radeon R9 Nano / FURY/FURY X]
```

#### Vendor/Device ID Lookup

```bash
root@pve:~# lspci -n -s 05:00
05:00.0 0300: 10de:1187 (rev a1)
05:00.1 0403: 10de:0e0a (rev a1)

root@pve:~# lspci -n -s 0b:00
0b:00.0 0300: 1002:7300 (rev c8)
0b:00.1 0403: 1002:aae8
```

#### VFIO Configuration

Edit `/etc/modprobe.d/vfio.conf`:

```bash
options vfio-pci ids=10de:1187,10de:0e0a,1002:7300,1002:aae8 disable_vga=1
```

#### Apply Changes

Update ramdisk and reboot:

```bash
update-initramfs -u
reboot
```

---

## Guest Configuration

### VM Creation Requirements

- **Machine type:** q35
- **BIOS:** OVMF (UEFI)
- **CPU Type:** host
- Add an **EFI disk** when changing the BIOS type

![System Tab Configuration](https://matt.olan.me/post/proxmox-gpu-passthrough-guide/image-1.png)

![CPU Tab Configuration](https://matt.olan.me/post/proxmox-gpu-passthrough-guide/image-2.png)

### Post-Installation Steps

1. Enable **RDP** (VNC console becomes unavailable after GPU passthrough)
2. Shutdown the VM
3. Add **PCI Device** in the Hardware tab
4. Select the GPU bus ID and check **All Functions**

![PCI Device Selection](https://matt.olan.me/post/proxmox-gpu-passthrough-guide/image.png)

### Example Final VM Configuration

```ini
agent: 1
balloon: 0
bios: ovmf
boot: order=scsi0
cores: 8
cpu: host
efidisk0: local-lvm:vm-101-disk-1,size=4M
hostpci0: 0b:00,pcie=1,x-vga=1
machine: pc-q35-5.2
memory: 16384
name: myvm
net0: virtio=3A:E0:E6:77:D6:DD,bridge=vmbr0,firewall=1
numa: 0
ostype: win10
scsi0: local-lvm:vm-101-disk-0,backup=0,cache=writeback,discard=on,size=256G,ssd=1
scsihw: virtio-scsi-pci
smbios1: uuid=ad6efb1d-ad9a-4d30-b838-b5e196feb451
sockets: 1
vmgenid: 02e96114-94ed-4c18-b726-4bde08116748
```

---

## References

- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/Pci_passthrough)
- [The Ultimate Beginner's Guide to GPU Passthrough (Reddit)](https://www.reddit.com/r/homelab/comments/b5xpua/the_ultimate_beginners_guide_to_gpu_passthrough/)
- [Proxmox Performance Tweaks Wiki](https://pve.proxmox.com/wiki/Performance_Tweaks)
