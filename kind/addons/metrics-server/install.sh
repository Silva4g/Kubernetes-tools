#!/usr/bin/env bash
# Instala o metrics-server com o values.yaml desta pasta.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-lab}"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server >/dev/null 2>&1 || true
helm repo update metrics-server >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server \
  --kube-context "$KUBE_CONTEXT" \
  --namespace kube-system \
  -f "$DIR/values.yaml" \
  --wait --timeout 5m
