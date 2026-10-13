# ValidatingPolicy
**O que é:** verifica se o recurso obedece a regras escritas em CEL. Se não
obedecer, nega, avisa ou só registra.

**Quando usar:**
- Padrões obrigatórios: labels, resources/limits, proibir `latest`, proibir `hostNetwork`/`privileged`.
- Segurança: Pod Security, registries permitidos, quem pode criar o quê.
- Começar em `Audit` para ver o impacto e só depois passar para `Deny`.

**Quando não usar:** se você quer **corrigir** o recurso em vez de recusar, use MutatingPolicy.
Para checar assinatura de imagem, use ImageValidatingPolicy.

## Opções (`spec`)

| Campo | Tipo | O que faz |
|---|---|---|
| `validations[]` | lista | As regras. Cada uma precisa de `expression` (deve dar `true` para passar) |
| `validations[].expression` | CEL → bool | `true` = válido |
| `validations[].message` | string | Mensagem fixa de erro (uma linha só) |
| `validations[].messageExpression` | CEL → string | Mensagem dinâmica. Tem prioridade sobre o `message` |
| `validations[].reason` | string | Código da resposta HTTP: `Unauthorized`, `Forbidden`, `Invalid`, `RequestEntityTooLarge` |
| `validationActions` | lista | `Deny` (bloqueia), `Audit` (só registra no report), `Warn` (devolve um aviso no kubectl e deixa passar). Dá para combinar, ex.: `[Audit, Warn]` |
| `matchConstraints` | objeto | [Seleção](../README.md#seleção-matchconstraints) |
| `matchConditions[]` | lista | [Filtro fino](../README.md#filtro-fino-matchconditions) |
| `variables[]` | lista | [Reuso](../README.md#reuso-variables) |
| `auditAnnotations[]` | lista | [Anotações de auditoria](../README.md#auditannotations) |
| `failurePolicy` | `Fail` \| `Ignore` | [Comportamento em erro](../README.md#comportamento-em-erro-failurepolicy) |
| `webhookConfiguration.timeoutSeconds` | int | [Timeout](../README.md#webhookconfigurationtimeoutseconds) |
| `evaluation.admission.enabled` | bool (`true`) | Avalia no admission |
| `evaluation.background.enabled` | bool (`true`) | Background scan + PolicyReport |
| `evaluation.mode` | `Kubernetes` \| `JSON` \| `HTTP` \| `Envoy` | `Kubernetes` (padrão) avalia recursos do cluster. `JSON` avalia qualquer JSON/YAML (ex.: plano do Terraform) via `kyverno` CLI. `HTTP`/`Envoy` são para usar o Kyverno como autorizador de requests HTTP |
| `autogen.podControllers.controllers` | lista | [Autogen](../README.md#autogenpodcontrollerscontrollers) para Deployments etc. |
| `autogen.validatingAdmissionPolicy.enabled` | bool (`false`) | Gera um `ValidatingAdmissionPolicy` **nativo**, que o API server executa sem chamar o webhook do Kyverno (mais rápido e continua funcionando se o Kyverno cair). Não funciona junto com `podControllers` nem com as CEL libraries do Kyverno |

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/validating-policy/policy.yaml
kubectl get validatingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/validating-policy/resources.yaml
```
Remover:
```shell
kubectl delete -f kyverno/policies/validating-policy/
```

## Pegadinhas
- O Kyverno para na primeira validação que falha; a mensagem mostra só ela.
- Comece com `validationActions: [Audit]` e veja `kubectl get policyreports -A` antes de passar para `Deny`.
