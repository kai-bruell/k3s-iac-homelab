# Production Cluster

Live Production Environment - wird wie ein echter Production Cluster behandelt.

## Eigenschaften

- **Zweck**: Live Services (später)
- **Stabilität**: Darf NIEMALS kaputt gehen
- **FluxCD Sync**: Konservativ (10 Minuten Interval)

## Terraform

```bash
cd terraform/environments/production
terraform apply
```

## Verwendung

- Nur getestete und validierte Änderungen
- Änderungen müssen durch Dev → Staging gegangen sein
- Manuelle Approval vor kritischen Updates
- Monitoring und Alerting

## Deployment Flow

```
Development → Staging → Production (mit Approval)
```

## FluxCD Bootstrap

```bash
# Nach Cluster-Start
export KUBECONFIG=~/.kube/k3s-prod-config
flux bootstrap github \
  --owner=kai-bruell \
  --repository=k3s-iac-homelab \
  --branch=main \
  --path=kubernetes/clusters/production
```

## Wichtig

- Keine direkten kubectl apply Befehle
- Alle Änderungen über Git
- Rollbacks über Git Revert
- Production läuft langfristig (nicht täglich destroyen)
