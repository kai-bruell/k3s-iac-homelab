# k3s-iac-homelab

Homelab infrastructure for k3s cluster on Flatcar Linux VMs using OpenTofu and GitOps.

## Stack

- **OpenTofu** - Infrastructure as Code (open-source Terraform fork)
- **libvirt/KVM** - Virtualization
- **Flatcar Container Linux** - Minimal, immutable OS
- **k3s** - Lightweight Kubernetes
- **Butane/Ignition** - Declarative VM provisioning
- **FluxCD** - GitOps continuous delivery

## Structure

```
homelab/
├── butane-configs/      # VM provisioning (Ignition)
│   ├── k3s-server/     # Control plane configuration
│   └── k3s-agent/      # Worker node configuration
│
├── terraform/
│   ├── modules/
│   │   ├── flatcar-vm/      # Reusable VM module
│   │   └── k3s-cluster/     # k3s cluster orchestration
│   └── environments/
│       ├── development/     # Local testing
│       ├── staging/         # Pre-production (planned)
│       └── production/      # Live environment (planned)
│
├── kubernetes/          # GitOps manifests (FluxCD)
│   ├── flux-system/    # FluxCD bootstrap
│   ├── clusters/       # Environment-specific configs
│   ├── infrastructure/ # Base services (Traefik, etc.)
│   └── apps/          # Applications
│
└── docs/              # Documentation
```

## Current Status

- ✅ OpenTofu modules (flatcar-vm, k3s-cluster)
- ✅ Development environment working
- ✅ Storage pool architecture fixed
- ✅ GitOps with FluxCD
- ✅ Automated kubeconfig download
- ⏳ Staging environment
- ⏳ Production environment

## Workflow

**Trunk-Based Development**
- Single `main` branch (always deployable)
- Direct commits to main
- Environments: dev → staging → production

## Quick Start

```bash
# Enter development environment
devbox shell

# Deploy development cluster
cd terraform/environments/development
tofu init
tofu apply

# Access cluster (kubeconfig automatically downloaded)
export KUBECONFIG=~/.kube/k3s-dev-config
kubectl get nodes

# Verify FluxCD
kubectl get kustomizations -A
flux get sources git
```

## Documentation

See [docs/README.md](docs/README.md) for detailed documentation.
