# metrics-server
Habilita `kubectl top` e o HPA.

Para ver todos os valores do chart:
```shell
helm show values metrics-server/metrics-server
```

## Instalacao
```shell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo update metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f kind/addons/metrics-server/values.yaml
```

## Verificar
```shell
kubectl top nodes
```
