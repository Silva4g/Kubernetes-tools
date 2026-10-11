# Atalhos para kind/lab.sh. Variáveis repassadas, ex.:
#   make up CNI=calico PROXY_MODE=ipvs WORKERS=3
#   make up CONTROL_PLANES=3 ADDONS=metrics-server,metallb
export CLUSTER_NAME CONTROL_PLANES WORKERS CNI PROXY_MODE POD_SUBNET \
       SERVICE_SUBNET API_PORT NODE_IMAGE INGRESS_PORTS ADDONS \
       CILIUM_VERSION CALICO_VERSION METALLB_POOL

LAB := ./kind/lab.sh

.PHONY: up down recreate config status cni addons
up:       ; $(LAB) up
down:     ; $(LAB) down
recreate: down up
config:   ; $(LAB) config
status:   ; $(LAB) status
cni:      ; $(LAB) cni
addons:   ; $(LAB) addons
