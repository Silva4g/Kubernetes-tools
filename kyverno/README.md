# Kyverno
Testes de policy do kyverno e suas funcionalidades

## Instalacao
Apos a instalacao do kind rode:
```aiignore
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace
```

##  Policy types
- ValidatingPolicy
- MutatingPolicy
- GeneratingPolicy
- DeletingPolicy
- ImageValidatingPolicy
- CEL Libraries