# Calico
CNI alternativo ao Cilium. Precisa do kube-proxy, então antes de criar o cluster
troque no `kind/cluster.yaml`:
```yaml
kubeProxyMode: "iptables"   # ou ipvs / nftables
```

## Instalacao
Primeiro o operator, depois a `Installation` com o IP pool:
```shell
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml
kubectl -n tigera-operator rollout status deploy/tigera-operator
kubectl apply -f kind/cni/calico/installation.yaml
```

## Verificar
```shell
kubectl get tigerastatus
kubectl get pods -n calico-system
```
