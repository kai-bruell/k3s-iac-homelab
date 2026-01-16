#!/usr/bin/env bash
set -euo pipefail

# Konfiguration
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/k3s-dev-config}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
FLUX_PATH="${FLUX_PATH:-./kubernetes}"

check_prerequisites() {
    echo "Prüfe Voraussetzungen..."

    [[ -z "${GITHUB_OWNER:-}" ]] && { echo "Fehler: GITHUB_OWNER nicht gesetzt"; exit 1; }
    [[ -z "${GITHUB_REPOSITORY:-}" ]] && { echo "Fehler: GITHUB_REPOSITORY nicht gesetzt"; exit 1; }
    [[ -z "${GITHUB_TOKEN:-}" ]] && { echo "Fehler: GITHUB_TOKEN nicht gesetzt"; exit 1; }
    [[ ! -f "$KUBECONFIG" ]] && { echo "Fehler: KUBECONFIG nicht gefunden: $KUBECONFIG"; exit 1; }
    command -v kubectl &>/dev/null || { echo "Fehler: kubectl nicht gefunden"; exit 1; }
    command -v flux &>/dev/null || { echo "Fehler: flux nicht gefunden"; exit 1; }

    export KUBECONFIG
    echo "OK"
}

wait_for_cluster() {
    echo "Warte auf Nodes..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    echo "Warte auf System Pods..."
    kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=180s
}

bootstrap_flux() {
    echo "Starte FluxCD Bootstrap..."
    echo "  Owner:      $GITHUB_OWNER"
    echo "  Repository: $GITHUB_REPOSITORY"
    echo "  Branch:     $GITHUB_BRANCH"
    echo "  Path:       $FLUX_PATH"

    flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPOSITORY" \
        --branch="$GITHUB_BRANCH" \
        --path="$FLUX_PATH" \
        --personal

    echo "FluxCD Bootstrap erfolgreich!"
}

main() {
    echo "=== FluxCD Bootstrap ==="
    check_prerequisites
    wait_for_cluster
    bootstrap_flux
    echo "=== Fertig ==="
}

main "$@"
