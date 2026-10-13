# GeneratingPolicy
**O que é:** quando um recurso **gatilho** é criado ou alterado, gera outros
recursos (os **downstream**). Pode mantê-los sincronizados.

**Quando usar:**
- Namespace novo ganha NetworkPolicy default-deny, ResourceQuota, LimitRange, RoleBinding.
- Copiar Secret de registry (imagePullSecret) ou ConfigMap de CA para todos os namespaces.
- Criar PodDisruptionBudget para todo Deployment.

**Quando não usar:** para criar coisas uma vez só, no deploy, use Helm/GitOps.
A GeneratingPolicy vale a pena quando o gatilho é dinâmico (namespaces criados
por times, por exemplo).

## Formas de gerar (`generate[]`)

| Forma | Como |
|---|---|
| `expression` | CEL que chama `generator.Apply(namespace, [recursos])`. Os recursos são maps com `apiVersion`, `kind` e `metadata`, com `dyn()` em volta dos valores |
| `template` | YAML em `template.value` (aceita vários documentos com `---`). Com `interpolate: cel`, os trechos `(( expr ))` viram CEL: `namespace: (( variables.ns ))` |
| Clonar | `generator.Apply(ns, [resource.Get("v1", "secrets", "default", "regcred")])` |

## Opções (`spec`)

| Campo | Tipo | O que faz |
|---|---|---|
| `generate[]` | lista (obrigatório) | O que gerar |
| `generate[].expression` | CEL | Usa `generator.Apply` |
| `generate[].template.value` | string YAML | Recursos em YAML |
| `generate[].template.interpolate` | `none` \| `cel` (`none`) | Ativa os placeholders `(( ))` |
| `matchConstraints` | objeto | Gatilho |
| `matchConditions[]` | lista | Filtro fino |
| `variables[]` | lista | Reuso |
| `auditAnnotations[]` | lista | Auditoria |
| `webhookConfiguration.timeoutSeconds` | int | Timeout |
| `useServerSideApply` | bool (`false`) | Cria/atualiza os downstream com apply em vez de create/update |
| `evaluation.admission.enabled` | bool (`true`) | Gera no admission |
| `evaluation.generateExisting.enabled` | bool (`false`) | Ao criar a policy, gera também para os gatilhos que **já existem** |
| `evaluation.synchronize.enabled` | bool (`false`) | Mantém os downstream sincronizados (veja abaixo) |
| `evaluation.orphanDownstreamOnPolicyDelete.enabled` | bool (`false`) | Com synchronize ligado: apagar a policy **não** apaga os gerados |
| `evaluation.skipBackgroundRequests` | bool (`true`) | Igual ao da MutatingPolicy |

## O que o `synchronize: true` faz

| Evento | Recurso gerado por dados | Recurso clonado |
|---|---|---|
| Alguém apaga/edita o gerado | Recriado / revertido | Recriado / revertido |
| Gatilho apagado | Gerado apagado | Gerado apagado |
| Origem do clone alterada | — | Gerado atualizado |
| Policy alterada | Gerado atualizado | Mantido |
| Policy apagada | Apagado (exceto com `orphanDownstreamOnPolicyDelete`) | Mantido |

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/generating-policy/policy.yaml
kubectl get generatingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/generating-policy/resources.yaml
```
Conferir: `kubectl -n team-a get networkpolicy`

Remover:
```shell
kubectl delete -f kyverno/policies/generating-policy/
```

## Pegadinhas
- Cada recurso gerado precisa de `apiVersion`, `kind` e `metadata`. Use `dyn()` em volta dos valores do map para o CEL não reclamar de tipos misturados.
- Sem `generateExisting`, os namespaces que já existiam antes da policy não ganham nada.
