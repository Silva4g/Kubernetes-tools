# Kind
Cluster local para testar as ferramentas do repositório, configurado como se fosse
um cluster kubeadm: sem CNI padrão, sem kube-proxy e com patches do kubeadm.

A config fica em `cluster.yaml` (1 control-plane + 2 workers).

## Instalacao
Criar o cluster:
```shell
kind create cluster --config kind/cluster.yaml
```
Os nós vão ficar `NotReady` até instalar um CNI:
- [Cilium](cni/cilium/README.md) (padrão, substitui o kube-proxy)
- [Calico](cni/calico/README.md) (precisa do kube-proxy, ajuste o `kubeProxyMode`)

Conferir se os nós ficaram Ready:
```shell
kubectl get nodes -o wide
```

## Addons
- [metrics-server](addons/metrics-server/README.md): `kubectl top` e HPA
- [MetalLB](addons/metallb/README.md): Services do tipo LoadBalancer

## Atalho (script)
O `lab.sh` faz tudo acima de uma vez (cluster + CNI + addons):
```shell
make up                                   # Cilium sem kube-proxy + metrics-server
make up CNI=calico PROXY_MODE=ipvs WORKERS=3
make up CONTROL_PLANES=3 ADDONS=metrics-server,metallb
make config                               # só mostra o kind config gerado
make status
make down
```

| Variável         | Default          | Valores                                   |
|------------------|------------------|-------------------------------------------|
| `CLUSTER_NAME`   | `lab`            |                                           |
| `CONTROL_PLANES` | `1`              | `>1` cria HA com haproxy na frente        |
| `WORKERS`        | `2`              | distribuídos nas zonas `lab-a/b/c`        |
| `CNI`            | `cilium`         | `cilium`, `calico`, `kindnet`, `none`     |
| `PROXY_MODE`     | `none` (Cilium) / `iptables` | `none`, `iptables`, `ipvs`, `nftables` |
| `POD_SUBNET`     | `10.244.0.0/16`  |                                           |
| `SERVICE_SUBNET` | `10.96.0.0/12`   |                                           |
| `NODE_IMAGE`     | padrão do kind   | ex.: `kindest/node:v1.32.0`               |
| `INGRESS_PORTS`  | `true`           | publica 80/443 do 1º control-plane        |
| `ADDONS`         | `metrics-server` | pastas de `addons/`, separadas por vírgula |

Cada CNI/addon também tem seu `install.sh`, que dá para rodar sozinho
(ex.: `kind/addons/metallb/install.sh`).

## Remover
```shell
kind delete cluster --name lab
```
