# Infrastructure

Basis-Services die vor den Applikationen deployed werden müssen.

## Struktur

```
infrastructure/
├── configs/       # Namespaces, ConfigMaps, CRDs
└── controllers/   # Ingress Controller, Storage, etc.
```

## Deployment Reihenfolge

1. **configs** - Namespaces und CRDs zuerst
2. **controllers** - Traefik, Longhorn (später)
3. **apps** - Applikationen (abhängig von infrastructure)

## Was gehört hierher?

- **Ingress Controller** (Traefik)
- **Storage** (Longhorn - später)
- **Service Mesh** (später)
- **Monitoring** (Prometheus/Grafana - später)
- **Cert Manager** (TLS Certificates - später)

## FluxCD Dependencies

Apps warten automatisch bis Infrastructure bereit ist:

```yaml
# In apps/kustomization.yaml
dependsOn:
  - name: infrastructure-controllers
```
