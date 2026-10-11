# Cilium
CNI baseado em eBPF. Aqui ele também substitui o kube-proxy e sobe o Hubble
(observabilidade de rede).

O `values.yaml` tem só o que foi alterado. Para ver todos os valores do chart:
```shell
helm show values cilium/cilium --version 1.20.2
```

## Instalacao
```shell
helm repo add cilium https://helm.cilium.io
helm repo update cilium
helm install cilium cilium/cilium --version 1.20.2 \
  --namespace kube-system \
  -f kind/cni/cilium/values.yaml
```

## Verificar
```shell
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status
```
A linha `KubeProxyReplacement: True` confirma que o kube-proxy foi substituído.

Hubble UI:
```shell
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```
