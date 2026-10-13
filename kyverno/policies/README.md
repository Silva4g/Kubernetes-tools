# Policies CEL do Kyverno
Policies baseadas em CEL (`policies.kyverno.io/v1`). Cada pasta tem um
`README.md` com o que a policy é, quando usar e **todas** as opções do `spec`,
mais um exemplo testado (`policy.yaml` + `resources.yaml`).

> Baseado no schema dos CRDs do chart **3.9.1 (Kyverno v1.19.1)**. Para conferir
> no seu cluster: `kubectl explain validatingpolicy.spec --recursive`

| Pasta | O que é |
|---|---|
| [validating-policy](validating-policy/) | Bloquear/auditar recursos fora do padrão |
| [mutating-policy](mutating-policy/) | Alterar recursos antes de salvar |
| [generating-policy](generating-policy/) | Criar recursos a partir de outro |
| [deleting-policy](deleting-policy/) | Apagar recursos periodicamente |
| [image-validating-policy](image-validating-policy/) | Verificar assinatura/attestations de imagens |
| [cel-libraries](cel-libraries/) | Funções extras do Kyverno para o CEL |
| [policy-exception](policy-exception/) | Exceções sem editar a policy |

Aplique **uma policy por vez**: uma interfere na outra (a validating bloqueia os
pods de teste das outras).

---

## Visão geral: qual policy usar

| Quero... | Policy | Quando roda | Exemplo |
|---|---|---|---|
| Bloquear/auditar recursos fora do padrão | `ValidatingPolicy` | Admission + background scan | [validating-policy](validating-policy/) |
| Alterar o recurso antes de salvar (defaults, labels) | `MutatingPolicy` | Admission (+ existentes, opcional) | [mutating-policy](mutating-policy/) |
| Criar recursos a partir de outro (NetworkPolicy por namespace, copiar Secret) | `GeneratingPolicy` | Admission (+ existentes, opcional) | [generating-policy](generating-policy/) |
| Apagar recursos periodicamente (TTL, limpeza) | `DeletingPolicy` | Cron (cleanup-controller) | [deleting-policy](deleting-policy/) |
| Exigir imagem assinada / com SBOM / attestation | `ImageValidatingPolicy` | Admission + background scan | [image-validating-policy](image-validating-policy/) |
| Abrir exceção para uma policy sem editá-la | `PolicyException` | Junto com a policy | [policy-exception](policy-exception/) |

**Cluster vs Namespaced:** todas, exceto a PolicyException, têm uma versão
`Namespaced*` (`NamespacedValidatingPolicy`, `NamespacedMutatingPolicy`,
`NamespacedGeneratingPolicy`, `NamespacedDeletingPolicy`,
`NamespacedImageValidatingPolicy`). Os campos são os mesmos, mas a versão
namespaced só age no próprio namespace.
- **Cluster:** regras da plataforma, que valem para todo mundo (criadas pelo admin).
- **Namespaced:** regras do time, que o dono do namespace gerencia sem precisar de cluster-admin.

**Versus ClusterPolicy (`kyverno.io/v1`):** a ClusterPolicy antiga usa
padrões YAML/JMESPath (`validate.pattern`, `mutate.patchStrategicMerge`...).
As policies CEL seguem o formato do `ValidatingAdmissionPolicy` /
`MutatingAdmissionPolicy` nativos do Kubernetes e são o caminho recomendado
para policies novas.

---

## Conceitos comuns a todas

### Seleção: `matchConstraints`
Define **quais requests** a policy avalia. Precisa bater em todos os critérios.

| Campo | O que faz |
|---|---|
| `resourceRules[]` | Recursos + operações que entram. Bate se qualquer regra bater |
| `excludeResourceRules[]` | Recursos que saem. Tem prioridade sobre o `resourceRules` |
| `namespaceSelector` | Filtra pelas labels do **namespace** do objeto (no próprio Namespace, usa as labels dele) |
| `objectSelector` | Filtra pelas labels do **objeto** (avalia o objeto novo e o antigo) |
| `matchPolicy` | `Equivalent` (padrão): também pega a mesma coisa por outra API/versão. `Exact`: só a regra exata |

Campos de cada `resourceRules[]` / `excludeResourceRules[]`:

| Campo | Valores |
|---|---|
| `apiGroups` | `['']` para o core (pods, configmaps...), `['apps']`, `['*']` |
| `apiVersions` | `['v1']`, `['*']` |
| `operations` | `CREATE`, `UPDATE`, `DELETE`, `CONNECT`, `*` |
| `resources` | `pods`, `pods/log` (subresource), `pods/*`, `*/scale`, `*` |
| `resourceNames` | Lista de nomes específicos (vazio = todos) |
| `scope` | `Cluster`, `Namespaced`, `*` |

### Filtro fino: `matchConditions`
Lista de `{name, expression}` em CEL que precisa dar `true` para a policy rodar.
Serve para o que labels não resolvem, por exemplo: "só pods sem a anotação X".
Roda **antes** de `variables` e, por isso, não pode usar `variables`.

### Reuso: `variables`
Lista de `{name, expression}`. O resultado fica em `variables.<name>` e é
calculado só quando é usado (lazy). Serve para não repetir expressões e para
buscar dados uma vez só (ex.: `resource.Get`).

### Variáveis disponíveis no CEL

| Variável | Conteúdo |
|---|---|
| `object` | Objeto do request (`null` em DELETE) |
| `oldObject` | Objeto atual (`null` em CREATE) |
| `request` | Dados do request: `request.userInfo.username`, `request.operation`, `request.namespace`... |
| `namespaceObject` | Namespace do objeto (`null` para recursos cluster-scoped) |
| `variables` | Variáveis definidas em `spec.variables` |
| `authorizer` | Checa RBAC do usuário: `authorizer.group('apps').resource('deployments').check('delete').allowed()` |

### Comportamento em erro: `failurePolicy`
- `Fail` (padrão): se a policy der erro (expressão quebrada, timeout), o request é **negado**. É mais seguro.
- `Ignore`: em caso de erro, deixa passar. Isso evita travar o cluster se o Kyverno cair.

`failurePolicy` trata **erro**, não violação. A violação é tratada pelo `validationActions`.

### `webhookConfiguration.timeoutSeconds`
Tempo máximo do webhook (padrão 10s, máximo 30s). Aumente em policies que
chamam a rede (verificar imagem, `http.Get`).

### `evaluation`
Controla **onde** a policy roda. Os campos mudam por tipo e estão detalhados em cada seção.
- `admission.enabled` (padrão `true`): avalia no momento do create/update.
- `background.enabled` (padrão `true`): reavalia periodicamente os recursos que já existem e grava o resultado em `PolicyReport`. Desligue se a regra usa algo que só existe no request (ex.: `request.userInfo`).

### `autogen.podControllers.controllers`
Você escreve a regra para `Pod` e o Kyverno gera a mesma regra para quem cria pods:
`deployments`, `statefulsets`, `daemonsets`, `jobs`, `cronjobs`, `replicasets`,
`replicationcontrollers`. A expressão `object.spec.containers` vira
`object.spec.template.spec.containers` automaticamente. A vantagem é que o
erro aparece no `kubectl apply` do Deployment, e não depois, quando o
ReplicaSet tenta criar o pod.

### `auditAnnotations`
Lista de `{key, valueExpression}`. Grava valores calculados no audit log do
API server e nos resultados do PolicyReport. Serve para registrar contexto
sem bloquear nada.

---

## Docs
- Tipos de policy: https://kyverno.io/docs/policy-types/
- CEL libraries: https://kyverno.io/docs/policy-types/cel-libraries/
