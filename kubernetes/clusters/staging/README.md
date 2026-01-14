
# Staging Cluster

Pre-Production Environment für finale Tests vor Production Deployment.

## Eigenschaften

- **Zweck**: Realistische Tests in Production-ähnlicher Umgebung
- **Stabilität**: Sollte nicht kaputt gehen
- **FluxCD Sync**: Normal (5 Minuten Interval)

## OpenTofu

```bash
cd terraform/environments/staging
tofu apply
```

## Verwendung

- Dress Rehearsal vor Production
- Integration Tests
- Performance Tests
- QA und Smoke Tests

## Deployment Flow

```
Development (getestet) → Staging (validiert) → Production
```

## FluxCD Bootstrap

```bash
# Nach Cluster-Start
export KUBECONFIG=~/.kube/k3s-staging-config
flux bootstrap github \
  --owner=kai-bruell \
  --repository=k3s-iac-homelab \
  --branch=main \
  --path=kubernetes/clusters/staging
```
