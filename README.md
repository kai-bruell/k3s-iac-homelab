# k3s-iac-homelab

Homelab infrastructure for k3s cluster on Flatcar Linux VMs using Terraform.

## Stack

- **Terraform** - Infrastructure as Code
- **libvirt/KVM** - Virtualization
- **Flatcar Container Linux** - Minimal, immutable OS
- **k3s** - Lightweight Kubernetes
- **Butane** - Ignition config generation

## Structure

```
terraform/
├── modules/
│   ├── flatcar-vm/      # Reusable VM module
│   └── k3s-cluster/     # k3s cluster orchestration
└── environments/
    ├── development/     # Local testing
    ├── staging/         # Pre-production (planned)
    └── production/      # Live environment (planned)
```

***IN DER STRUKTUR HAT SICH ETWAS GEÄNDERT. ES IST ./KUBERNETES HINZUGEKOMMEN.

## Current Status

- ✅ Terraform modules (flatcar-vm, k3s-cluster)
- ✅ Development environment working
- ✅ Storage pool architecture fixed
- ⏳ Staging environment 
- ⏳ Production environment
- ⏳ GitOps with FluxCD ***FLUXCD IST INZWISCHEN EINGERICHTET.

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
terraform init
terraform apply

# Access cluster

***TERRAFORM WILL AUTOMATICALLY COPY THE KUBECONFIG TO '/.kube/k3s-dev-config'

export KUBECONFIG=~/.kube/k3s-dev-config
kubectl get nodes
```
