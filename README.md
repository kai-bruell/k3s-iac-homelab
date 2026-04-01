# k3s-iac-homelab

Homelab Infrastructure as Code: k3s cluster on Flatcar Linux, NixOS workstation VMs, dotfiles and Distrobox environments — all on Proxmox, managed with OpenTofu and GitOps.

(WARNING: This Project is under heavy construction and refactoring) 

This Project is documenting well enough how which tools are working conceptionally. I am planning to Build a new homelab repository from scratch again for better understanding.


## Stack

- **OpenTofu** - Infrastructure as Code (open-source Terraform)
- **Proxmox** - Hypervisor for all VMs
- **Flatcar Container Linux** - Minimal, immutable OS (k3s nodes)
- **NixOS** - Declarative OS for standalone VMs (via Nix Flake)
- **k3s** - Lightweight Kubernetes
- **Butane/Ignition** - Declarative Flatcar VM provisioning
- **nixos-anywhere + disko** - Fully automated NixOS VM deployment
- **FluxCD** - GitOps continuous delivery
- **Chezmoi** - Dotfile management (Sway, nvim, zsh, foot, waybar, tmux)
- **Distrobox** - Declarative container environments (Arch Rolling)

## Structure

```
.
├── butane-configs/          # Flatcar VM provisioning (Ignition)
│   ├── k3s-server/         # Control plane node
│   └── k3s-agent/          # Worker node
│
├── nixos/                   # NixOS Flake (nixos-anywhere deployable)
│   ├── modules/            # Shared modules (base, hardware-vm)
│   └── hosts/
│       ├── nixos-minimal/  # Minimal base template
│       ├── nixos-example/  # Template for new hosts
│       └── videoediting/   # Video editing workstation (Sway, Sunshine, Distrobox)
│
├── terraform/
│   ├── modules/
│   │   ├── flatcar-vm/     # Reusable Flatcar/Proxmox VM module
│   │   ├── k3s-cluster/    # k3s cluster orchestration
│   │   └── nixos-vm/       # NixOS VM module (nixos-anywhere)
│   └── environments/
│       ├── development/    # k3s dev cluster
│       ├── nixos-example/  # Example NixOS VM
│       └── videoediting/   # Video editing VM
│
├── kubernetes/              # GitOps manifests (FluxCD)
│   ├── flux-system/        # FluxCD bootstrap
│   ├── clusters/           # Environment-specific configs
│   ├── infrastructure/     # Base services (Traefik, etc.)
│   └── apps/              # Applications
│
├── dotfiles/                # Chezmoi-managed configs (Sway, nvim, zsh, …)
├── distroboxes/             # Declarative Distrobox environments
├── scripts/                 # Helper scripts (Flux bootstrap, etc.)
└── devbox-container/        # Podman-based dev environment container
```

## Quick Start

### k3s Dev Cluster

```bash
devbox shell

cd terraform/environments/development
tofu init && tofu apply

export KUBECONFIG=~/.kube/k3s-dev-config
kubectl get nodes
```

### NixOS VMs

```bash
cd terraform/environments/videoediting   # or: nixos-example
cp terraform.tfvars.example terraform.tfvars
# edit with Proxmox credentials
tofu init && tofu apply
```

The `nixos-vm` module bootstraps a Debian cloud-init VM, then uses
`nixos-anywhere` to install NixOS from the Flake in `nixos/` — no pre-built template required.

