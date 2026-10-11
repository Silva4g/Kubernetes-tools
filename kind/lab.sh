#!/usr/bin/env bash
# Atalho para o que o kind/README.md descreve passo a passo.
# Com os defaults gera a mesma config de kind/cluster.yaml; as variáveis de
# ambiente permitem variar topologia, CNI e kube-proxy sem editar o arquivo.
#
# Uso: kind/lab.sh <up|down|config|status|cni|addons>
set -euo pipefail

KIND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-lab}"
CONTROL_PLANES="${CONTROL_PLANES:-1}"
WORKERS="${WORKERS:-2}"
# cilium | calico | kindnet | none (none = você instala o CNI na mão)
CNI="${CNI:-cilium}"
# none | iptables | ipvs | nftables
PROXY_MODE="${PROXY_MODE:-}"
POD_SUBNET="${POD_SUBNET:-10.244.0.0/16}"
SERVICE_SUBNET="${SERVICE_SUBNET:-10.96.0.0/12}"
API_PORT="${API_PORT:-6443}"
# Ex.: kindest/node:v1.32.0 (vazio = imagem padrão da versão do kind)
NODE_IMAGE="${NODE_IMAGE:-}"
# Publica 80/443 do primeiro control-plane no host (para ingress)
INGRESS_PORTS="${INGRESS_PORTS:-true}"
# Addons separados por vírgula (nomes das pastas em kind/addons)
ADDONS="${ADDONS:-metrics-server}"

GEN_DIR="$KIND_DIR/.generated"
CONFIG_FILE="$GEN_DIR/$CLUSTER_NAME.yaml"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

# Cilium substitui o kube-proxy; os outros CNIs precisam dele.
if [[ -z "$PROXY_MODE" ]]; then
  [[ "$CNI" == "cilium" ]] && PROXY_MODE=none || PROXY_MODE=iptables
fi

validate() {
  case "$CNI" in cilium|calico|kindnet|none) ;; *) die "CNI inválido: $CNI" ;; esac
  case "$PROXY_MODE" in none|iptables|ipvs|nftables) ;; *) die "PROXY_MODE inválido: $PROXY_MODE" ;; esac
  if [[ "$PROXY_MODE" == "none" && "$CNI" =~ ^(calico|kindnet)$ ]]; then
    die "$CNI precisa do kube-proxy. Use PROXY_MODE=iptables|ipvs|nftables ou CNI=cilium."
  fi
  (( CONTROL_PLANES >= 1 )) || die "CONTROL_PLANES precisa ser >= 1"
}

# Endpoint do API server visto de dentro do cluster. Com HA o kind cria um
# container haproxy "<nome>-external-load-balancer" na frente dos control-planes.
api_endpoint_host() {
  if (( CONTROL_PLANES > 1 )); then
    echo "$CLUSTER_NAME-external-load-balancer"
  else
    echo "$CLUSTER_NAME-control-plane"
  fi
}

render_config() {
  mkdir -p "$GEN_DIR"
  local disable_cni=true
  [[ "$CNI" == "kindnet" ]] && disable_cni=false

  {
    cat <<EOF
# Gerado por kind/lab.sh — referência comentada em kind/cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
networking:
  ipFamily: ipv4
  apiServerAddress: "127.0.0.1"
  apiServerPort: $API_PORT
  podSubnet: "$POD_SUBNET"
  serviceSubnet: "$SERVICE_SUBNET"
  disableDefaultCNI: $disable_cni
  kubeProxyMode: "$PROXY_MODE"
kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    controllerManager:
      extraArgs:
        bind-address: "0.0.0.0"
    scheduler:
      extraArgs:
        bind-address: "0.0.0.0"
    etcd:
      local:
        extraArgs:
          listen-metrics-urls: "http://0.0.0.0:2381"
  - |
    kind: KubeletConfiguration
    serializeImagePulls: false
  - |
    kind: KubeProxyConfiguration
    metricsBindAddress: "0.0.0.0:10249"
    ipvs:
      strictARP: true
nodes:
EOF
    local i
    for (( i = 1; i <= CONTROL_PLANES; i++ )); do
      echo "  - role: control-plane"
      [[ -n "$NODE_IMAGE" ]] && echo "    image: $NODE_IMAGE"
      if (( i == 1 )); then
        cat <<EOF
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
EOF
        if [[ "$INGRESS_PORTS" == "true" ]]; then
          cat <<EOF
    extraPortMappings:
      - { containerPort: 80, hostPort: 80, protocol: TCP }
      - { containerPort: 443, hostPort: 443, protocol: TCP }
EOF
        fi
      fi
    done
    local zones=(a b c)
    for (( i = 0; i < WORKERS; i++ )); do
      echo "  - role: worker"
      [[ -n "$NODE_IMAGE" ]] && echo "    image: $NODE_IMAGE"
      cat <<EOF
    labels:
      topology.kubernetes.io/region: lab
      topology.kubernetes.io/zone: lab-${zones[$(( i % 3 ))]}
EOF
    done
  } > "$CONFIG_FILE"
}

install_cni() {
  local ctx="kind-$CLUSTER_NAME"
  case "$CNI" in
    cilium)
      KUBE_CONTEXT="$ctx" API_HOST="$(api_endpoint_host)" PROXY_MODE="$PROXY_MODE" \
        "$KIND_DIR/cni/cilium/install.sh" ;;
    calico)
      KUBE_CONTEXT="$ctx" POD_SUBNET="$POD_SUBNET" "$KIND_DIR/cni/calico/install.sh" ;;
    kindnet) log "kindnet já vem instalado pelo kind" ;;
    none) log "CNI=none: nós ficarão NotReady até você instalar um CNI" ; return ;;
  esac
  log "Aguardando nós ficarem Ready..."
  kubectl --context "$ctx" wait --for=condition=Ready nodes --all --timeout=5m
}

install_addons() {
  local ctx="kind-$CLUSTER_NAME" addon
  [[ -z "$ADDONS" ]] && return
  IFS=',' read -ra list <<< "$ADDONS"
  for addon in "${list[@]}"; do
    [[ -x "$KIND_DIR/addons/$addon/install.sh" ]] || die "addon desconhecido: $addon"
    log "Instalando addon $addon"
    KUBE_CONTEXT="$ctx" "$KIND_DIR/addons/$addon/install.sh"
  done
}

cmd_up() {
  validate
  render_config
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    die "cluster '$CLUSTER_NAME' já existe (rode 'make down' antes)"
  fi
  log "Criando cluster $CLUSTER_NAME (cp=$CONTROL_PLANES workers=$WORKERS cni=$CNI kube-proxy=$PROXY_MODE)"
  kind create cluster --config "$CONFIG_FILE" --wait 0s
  install_cni
  install_addons
  cmd_status
}

cmd_down() {
  kind delete cluster --name "$CLUSTER_NAME"
}

cmd_status() {
  local ctx="kind-$CLUSTER_NAME"
  kubectl --context "$ctx" get nodes -o wide
  echo
  kubectl --context "$ctx" get pods -A -o wide
}

case "${1:-}" in
  up) cmd_up ;;
  down) cmd_down ;;
  config) validate; render_config; cat "$CONFIG_FILE" ;;
  status) cmd_status ;;
  cni) validate; install_cni ;;
  addons) install_addons ;;
  *) echo "Uso: $0 <up|down|config|status|cni|addons>" >&2; exit 1 ;;
esac
