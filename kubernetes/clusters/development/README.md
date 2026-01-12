
# Development Cluster

Lokales Development-Environment für schnelles Testing und Experimentieren.

## Eigenschaften

- **Zweck**: Schnelles Testen von neuen Features und Konfigurationen
- **Stabilität**: Darf kaputt gehen
- **FluxCD Sync**: Schnell (1 Minute Interval)

## Terraform

```bash
cd terraform/environments/development
terraform apply
```

## Verwendung

- Neue Helm Charts ausprobieren
- FluxCD Konfiguration testen
- Breaking Changes risikofrei testen
- Direktes Arbeiten und Experimentieren

## FluxCD Bootstrap

```bash
# Nach Cluster-Start
export KUBECONFIG=~/.kube/k3s-dev-config
flux bootstrap github \
  --owner=kai-bruell \
  --repository=k3s-iac-homelab \
  --branch=main \
  --path=kubernetes/clusters/development
```
