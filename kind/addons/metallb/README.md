# MetalLB
Dá IP para Services do tipo `LoadBalancer`, usando um pedaço da rede docker do kind.

No macOS esses IPs só são acessíveis de dentro da rede docker (dos nós ou de
outro container), não do host.

## Instalacao
Ver a subnet da rede do kind e, se precisar, ajustar a faixa no `pool.yaml`:
```shell
docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}'
```
Instalar e aplicar o pool:
```shell
helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm install metallb metallb/metallb --namespace metallb-system --create-namespace --wait
kubectl apply -f kind/addons/metallb/pool.yaml
```

## Verificar
```shell
kubectl create deploy web --image=nginx:alpine
kubectl expose deploy web --port 80 --type LoadBalancer
kubectl get svc web
```
O `EXTERNAL-IP` deve vir da faixa do pool.
