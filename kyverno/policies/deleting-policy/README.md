# DeletingPolicy
**O que é:** o **cleanup-controller** roda no horário do `schedule` (cron),
lista os recursos que batem com a policy e apaga os que passam nas
`conditions`. Não é admission: não bloqueia nem altera requests.

**Quando usar:**
- TTL: pods/jobs de teste, namespaces efêmeros de PR, ambientes de preview.
- Limpeza: ReplicaSets antigos, pods `Completed`/`Failed`, Secrets expirados.

**Atenção:** o cleanup-controller precisa de RBAC para listar/apagar o recurso
(veja `deleting-policy/rbac.yaml`). Sem isso, nada é apagado e o erro só
aparece no log do controller.

## Opções (`spec`)

| Campo | Tipo | O que faz |
|---|---|---|
| `schedule` | cron (obrigatório) | Quando roda. `'*/5 * * * *'` = a cada 5 min, `'0 3 * * *'` = todo dia às 3h |
| `matchConstraints` | objeto | Quais recursos listar (use `objectSelector`/`namespaceSelector` para restringir) |
| `conditions[]` | lista `{name, expression}` | CEL por recurso; apaga se **todas** derem `true`. Usa `object` (o recurso) e `variables` |
| `variables[]` | lista | Reuso (ex.: idade = `time.now() - timestamp(object.metadata.creationTimestamp)`) |
| `deletionPropagationPolicy` | `Foreground` \| `Background` \| `Orphan` | Como apagar os dependentes (pods de um Deployment etc.). `Orphan` apaga só o objeto e deixa os filhos |

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/deleting-policy/rbac.yaml
kubectl apply -f kyverno/policies/deleting-policy/policy.yaml
kubectl get deletingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/deleting-policy/resources.yaml
```
Conferir: `kubectl get pods -w` (o `temp-pod` some em ~2 min)

Remover:
```shell
kubectl delete -f kyverno/policies/deleting-policy/
```

## Pegadinhas
- O cleanup-controller **não tem permissão em pods por padrão**. Aplique o `rbac.yaml` desta pasta (ClusterRole agregada pela label `rbac.kyverno.io/aggregate-to-cleanup-controller`). Sem ele nada é apagado e o erro só aparece no log:
  `kubectl -n kyverno logs deploy/kyverno-cleanup-controller`
- Para ver a última execução: `kubectl get deletingpolicy <nome> -o jsonpath='{.status.lastExecutionTime}'`
