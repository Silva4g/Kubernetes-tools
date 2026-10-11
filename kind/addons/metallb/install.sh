#!/usr/bin/env bash
# Instala o MetalLB e aplica o pool.yaml desta pasta. A faixa de IPs é
# calculada a partir da rede docker "kind" (ou METALLB_POOL, se definido).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-lab}"
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }

subnet="$(docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -1)"
[[ -n "$subnet" ]] || { echo "não achei subnet IPv4 da rede docker kind" >&2; exit 1; }
prefix="$(cut -d. -f1-2 <<< "$subnet")"
pool="${METALLB_POOL:-$prefix.255.200-$prefix.255.250}"
echo "==> Rede kind: $subnet | pool MetalLB: $pool"

helm repo add metallb https://metallb.github.io/metallb >/dev/null 2>&1 || true
helm repo update metallb >/dev/null
helm upgrade --install metallb metallb/metallb \
  --kube-context "$KUBE_CONTEXT" \
  --namespace metallb-system --create-namespace \
  --wait --timeout 5m

sed "s|^    - [0-9].*|    - $pool|" "$DIR/pool.yaml" | k apply -f -
