
# Kubernetes GitOps Configuration

Dieses Verzeichnis enthält alle Kubernetes-Manifests, die von FluxCD verwaltet werden.

## Struktur

```
kubernetes/
├── clusters/          # Environment-spezifische Konfigurationen
├── infrastructure/    # Basis-Services (Traefik, etc.)
└── apps/             # Applikationen
```

## Workflow

1. **Änderungen in Git** - Manifests bearbeiten und committen
2. **FluxCD synchronisiert** - Automatisches Deployment ins Cluster
3. **Reconciliation** - FluxCD hält Cluster-Zustand mit Git in Sync

## Environments

- **Development** - Lokales Testing, darf kaputt gehen
- **Staging** - Pre-Production Tests, Generalprobe
- **Production** - Live Environment, maximale Stabilität

Alle drei Environments laufen lokal mit libvirt/KVM, aber werden wie separate Cluster behandelt.
