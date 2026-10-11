#!/usr/bin/env bash
# Instala o Cilium com o values.yaml desta pasta. O lab.sh sobrescreve só o
# que depende da topologia (endpoint do API server e kube-proxy).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-lab}"
API_HOST="${API_HOST:-lab-control-plane}"
PROXY_MODE="${PROXY_MODE:-none}"
CILIUM_VERSION="${CILIUM_VERSION:-1.20.2}"

kpr=false
[[ "$PROXY_MODE" == "none" ]] && kpr=true

helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update cilium >/dev/null

echo "==> Instalando Cilium $CILIUM_VERSION (kubeProxyReplacement=$kpr)"
helm upgrade --install cilium cilium/cilium \
  --kube-context "$KUBE_CONTEXT" \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  -f "$DIR/values.yaml" \
  --set kubeProxyReplacement="$kpr" \
  --set k8sServiceHost="$API_HOST" \
  --wait --timeout 10m
