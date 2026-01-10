# Infrastructure Controllers

Zentrale Controller Services für das Cluster.

## Geplante Controller

### Traefik (Ingress Controller)
- **Zweck**: HTTP/HTTPS Routing, Load Balancing
- **Status**: Geplant
- **Deployment**: Helm Chart via FluxCD
- **Config**: `traefik/`

### Longhorn (Storage)
- **Zweck**: Persistent Volumes, Distributed Storage
- **Status**: Später
- **Deployment**: Helm Chart via FluxCD
- **Config**: `longhorn/`

## Deployment Pattern

Jeder Controller hat sein eigenes Verzeichnis:

```
controllers/
└── traefik/
    ├── namespace.yaml           # Namespace erstellen
    ├── helm-repository.yaml     # Helm Repo hinzufügen
    ├── helm-release.yaml        # Chart deployen
    └── kustomization.yaml       # FluxCD Kustomization
```

## Warum Helm via FluxCD?

- Versionskontrolle in Git
- Automatische Updates
- Einfaches Rollback
- Konsistente Deployment-Methode
- Keine manuellen kubectl/helm Befehle nötig
