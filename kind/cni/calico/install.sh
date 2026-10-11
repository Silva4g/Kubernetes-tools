#!/usr/bin/env bash
# Instala o tigera-operator e aplica o installation.yaml desta pasta,
# trocando o cidr pelo POD_SUBNET usado no cluster.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-lab}"
POD_SUBNET="${POD_SUBNET:-10.244.0.0/16}"
CALICO_VERSION="${CALICO_VERSION:-v3.33.0}"
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }

echo "==> Instalando Calico $CALICO_VERSION"
k apply --server-side -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml"
k -n tigera-operator rollout status deploy/tigera-operator --timeout=5m
k wait --for=condition=Established crd/installations.operator.tigera.io --timeout=2m

sed "s|cidr: .*|cidr: $POD_SUBNET|" "$DIR/installation.yaml" | k apply -f -
