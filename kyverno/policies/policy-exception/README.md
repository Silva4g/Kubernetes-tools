# PolicyException
**O que é:** libera recursos específicos de uma policy **sem editar a policy**.
Fica em `policies.kyverno.io/v1`, `kind: PolicyException`, em um namespace.

**Quando usar:** um caso legítimo que viola a regra (ex.: o agente de
monitoramento precisa de `hostNetwork`). É melhor que um `exclude` na policy,
porque fica rastreável (quem pediu, até quando).

| Campo | O que faz |
|---|---|
| `policyRefs[]` (obrigatório) | `{kind, name}` das policies afetadas (ex.: `kind: ValidatingPolicy`) |
| `matchConditions[]` | CEL que define **quais recursos** são liberados |
| `images[]` | Imagens liberadas (`exceptions.allowedImages` no CEL da policy) |
| `allowedValues[]` | Valores liberados (`exceptions.allowedValues` no CEL da policy) |
| `expiresAt` | Data RFC3339 em que a exceção expira (`2026-12-31T00:00:00Z`) |
| `reportResult` | `skip` (padrão) ou `pass` no PolicyReport |
| `properties` | Metadados livres: motivo, ticket, quem aprovou |
| `evaluationMode` | Qual controller trata a exceção |

**As exceções vêm desligadas por padrão** (`--enablePolicyException=false`).
O `kubectl apply` da exceção funciona, mas aparece o aviso
`PolicyException resources would not be processed until it is enabled` e a
policy continua bloqueando. Para ligar, no `values.yaml` do chart:
```yaml
features:
  policyExceptions:
    enabled: true
    namespace: '*'   # ou um namespace só, onde as exceções são aceitas
```

## Testar
Precisa da feature ligada (veja acima) e da [validating-policy](../validating-policy/) aplicada:
```shell
kubectl apply -f kyverno/policies/validating-policy/policy.yaml
kubectl create ns kyv-test
kubectl apply -f kyverno/policies/policy-exception/exception.yaml
kubectl -n kyv-test run bad-pod --image=nginx:latest   # passa por causa da exceção
kubectl -n kyv-test run outro --image=nginx:latest     # continua bloqueado
```
