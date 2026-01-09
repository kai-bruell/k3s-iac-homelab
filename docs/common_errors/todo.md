# TODO: Improvements & Future Work

## Platform-Independent libvirt Deployment

**Problem:**
- Different Linux distributions ship different libvirt versions
- Ubuntu 22.04: libvirt 8.0.0 (March 2022)
- Latest upstream: libvirt 12.0+ (Dec 2024)
- AppArmor/SELinux configurations differ across distros

**Goal:**
- Reproducible, fixed libvirt version across all platforms
- Independent of distro package managers
- Similar to how Terraform already runs in devbox

**Approaches to investigate:**

### 1. Devbox/Nix (Preferred)
```json
{
  "packages": [
    "terraform@1.6.0",
    "libvirt@12.0.0",
    "qemu"
  ]
}
```

**Challenges:**
- libvirtd needs to run as system daemon (privileged access)
- Client-daemon version compatibility
- System integration (KVM modules, networking, AppArmor)

**Potential solution:**
- Install libvirt binaries via Nix (fixed version)
- Run libvirtd as user service or system service from Nix
- Use devbox services: `devbox services start libvirtd`

### 2. Nix/NixOS directly
- Better system-level integration than devbox
- Steep learning curve

### 3. Statically compiled binaries
- Distribution as single binary
- System integration remains complex

## Benefits
- ✓ Reproducible across Ubuntu/Fedora/Arch/etc.
- ✓ Fixed version eliminates version-specific bugs
- ✓ Security updates controlled, not distro-dependent
- ✓ Easier testing of newer libvirt versions

## Trade-offs
- More complex initial setup
- Need to manage security updates manually
- System-level components (KVM, AppArmor) still host-dependent

## Status
- Investigation needed
- Previously attempted in devbox, ran into issues
- Worth revisiting after current implementation is stable
