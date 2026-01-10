# Applications

Deine Applikationen und Services.

## Struktur

Hier kommen später deine eigenen Services:

```
apps/
├── nextcloud/
├── homepage/
├── monitoring/
└── ...
```

## Dependencies

Apps werden erst deployed nachdem Infrastructure bereit ist:

```yaml
# kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
spec:
  dependsOn:
    - name: infrastructure-controllers  # Warte auf Traefik, etc.
  path: ./kubernetes/apps
```

## Deployment Pattern

Jede App hat ihr eigenes Verzeichnis mit allen benötigten Resources:

```
apps/
└── myapp/
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── kustomization.yaml
```

## Helm vs. Plain YAML

- **Helm Release**: Für komplexe Apps aus Helm Repos
- **Plain YAML**: Für eigene, einfache Services

Beides funktioniert mit FluxCD!
