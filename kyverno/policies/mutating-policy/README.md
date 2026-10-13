# MutatingPolicy
**O que é:** altera o recurso **antes** de ele ser salvo no etcd. Também pode
alterar recursos que já existem (mutateExisting).

**Quando usar:**
- Defaults: `imagePullPolicy`, `securityContext`, `resources`, tolerations.
- Adicionar labels/annotations (time, custo, `managed-by`).
- Injetar coisas: sidecar, variável de ambiente, volume.
- Alterar **outro** recurso quando algo acontece (ex.: criou um Secret, então anota um Deployment) com `mutateExisting` + `targetMatchConstraints`.

**Quando não usar:** se o usuário **precisa saber** que fez algo errado, use
ValidatingPolicy. Mutação esconde o problema.

## Tipos de mutação (`mutations[].patchType`)

| patchType | Como funciona | Quando usar |
|---|---|---|
| `ApplyConfiguration` | Você descreve o estado desejado com `Object{...}` e o Kyverno faz merge (estilo server-side apply). Listas com chave (containers por `name`) são mescladas | Na maioria dos casos: setar campos, adicionar labels |
| `JSONPatch` | Você devolve uma lista de `JSONPatch{op, path, value}` (`add`, `replace`, `remove`, `test`, `copy`, `move`) | Remover campos, mexer em posição de lista, lógica condicional |

## Opções (`spec`)

| Campo | Tipo | O que faz |
|---|---|---|
| `mutations[]` | lista | As mutações, aplicadas em ordem |
| `mutations[].patchType` | `ApplyConfiguration` \| `JSONPatch` | Tipo da mutação |
| `mutations[].applyConfiguration.expression` | CEL → `Object{}` | Estado desejado |
| `mutations[].jsonPatch.expression` | CEL → `[JSONPatch{}]` | Operações. Uma lista vazia `[]` não muda nada |
| `reinvocationPolicy` | `Never` \| `IfNeeded` | `IfNeeded`: roda de novo se outro webhook alterou o objeto depois (útil quando há vários mutadores) |
| `matchConstraints` | objeto | Recursos **gatilho** |
| `matchConditions[]` | lista | Filtro fino no gatilho |
| `targetMatchConstraints` | objeto | Recursos **alvo** (para mutar outro recurso, diferente do gatilho). Mesmos campos do `matchConstraints` + `expression` |
| `targetMatchConditions[]` | lista | Filtro CEL no alvo (usa `object` = alvo e pode usar `variables`) |
| `variables[]` | lista | Reuso |
| `auditAnnotations[]` | lista | Gravado no PolicyReport depois da mutação |
| `failurePolicy` | `Fail` \| `Ignore` | Em erro |
| `webhookConfiguration.timeoutSeconds` | int | Timeout |
| `evaluation.admission.enabled` | bool (`true`) | Muta no admission |
| `evaluation.background.enabled` | bool (`true`) | Background |
| `evaluation.mutateExisting.enabled` | bool (`false`) | Muta recursos **já existentes**. Sem `targetMatchConstraints`, muta os do `matchConstraints` |
| `evaluation.skipBackgroundRequests` | bool (`true`) | Ignora requests do próprio background-controller. Coloque `false` para o mutateExisting reagir a eles |
| `evaluation.useServerSideApply` | bool | Usa server-side apply de verdade, o que permite setar campos atômicos (ex.: `args` de container) que o ApplyConfiguration padrão rejeita |
| `evaluation.mode` | `Kubernetes` \| `JSON` | Igual ao da ValidatingPolicy |
| `autogen.podControllers.controllers` | lista | Autogen para Deployments etc. |
| `autogen.mutatingAdmissionPolicy.enabled` | bool (`false`) | Gera um `MutatingAdmissionPolicy` nativo |

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/mutating-policy/policy.yaml
kubectl get mutatingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/mutating-policy/resources.yaml
```
Conferir: `kubectl get pod mutate-me -o yaml`

Remover:
```shell
kubectl delete -f kyverno/policies/mutating-policy/
```

## Pegadinhas
- Dentro de `Object{}` as chaves são identificadores CEL. Chave com `/` ou `.` vai entre crases: `` `lab/mutated-by`: "kyverno" ``, não entre aspas.
- Para ver o resultado: `kubectl get pod <nome> -o yaml` (a mutação não aparece no `kubectl apply`).
