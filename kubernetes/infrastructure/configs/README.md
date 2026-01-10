# Infrastructure Configs

Grundlegende Konfiguration die zuerst deployed werden muss.

## Inhalt

- **Namespaces** - Organisatorische Trennung
- **ConfigMaps** - Globale Konfiguration
- **Custom Resource Definitions** (CRDs) - Erweiterte Kubernetes Resourcen

## Beispiele

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-system
```

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
data:
  environment: "development"
  region: "local"
```

## Deployment

Wird als erstes von FluxCD deployed, da andere Resources darauf aufbauen.
