# Match statement (ClusterPolicy)
O bloco `match` define **em quais recursos** uma regra da `ClusterPolicy` /
`Policy` (`kyverno.io/v1`) é aplicada. O `exclude` tem a mesma estrutura e
**remove** recursos do que o `match` selecionou.

> **Deprecated:** ao aplicar uma `ClusterPolicy` no Kyverno v1.19, o próprio
> Kyverno avisa que ela será removida no futuro e recomenda migrar para as
> policies CEL. O equivalente do `match` nelas é o `matchConstraints`
> (veja [policies/README.md](../../policies/README.md#seleção-matchconstraints)).

## O exemplo desta pasta
`check-label.yaml` exige a label `env` em Pods e Deployments do namespace
`restricted-ns`:
```yaml
match:
  any:                       # basta UM item bater
    - resources:
        kinds: [Pod, Deployment]
        namespaces: [restricted-ns]
```
Testar:
```shell
kubectl apply -f kyverno/kodecloud/match-statemant/check-label.yaml
kubectl create ns restricted-ns
kubectl -n restricted-ns run sem-label --image=nginx                 # bloqueado
kubectl -n restricted-ns run com-label --image=nginx --labels=env=dev # passa
```

## `any` x `all`

| Forma | Lógica | Quando usar |
|---|---|---|
| `any: [...]` | **OU**: basta um item bater | O mais comum: "Pods **ou** Deployments" |
| `all: [...]` | **E**: todos os itens precisam bater | Combinar critérios de tipos diferentes: "no namespace X **e** feito pelo grupo Y" |
| `resources:` direto (sem any/all) | Um único filtro | Forma antiga, ainda aceita. Prefira `any` |

Dentro de **um** item, todos os campos precisam bater (E). Por exemplo,
`kinds: [Pod]` + `namespaces: [prod]` = Pod **e** no namespace prod.

`any` e `all` **não podem ficar juntos** no mesmo `match` ou `exclude`. O
Kyverno rejeita com `must not validate the schema (not)`.

## Opções de cada item

### `resources`: filtra pelo recurso

| Campo | O que faz | Exemplo |
|---|---|---|
| `kinds` | Tipos de recurso. Aceita `Kind`, `group/version/Kind` e subresource | `[Pod]`, `[apps/v1/Deployment]`, `[Pod/exec]` |
| `names` | Nomes do recurso (wildcard) | `["db-*"]` |
| `name` | Mesmo que `names`, mas um só (**deprecated**, use `names`) | `"db-*"` |
| `namespaces` | Nomes dos namespaces (wildcard) | `["team-*"]` |
| `namespaceSelector` | Labels do **namespace** | `matchLabels: {env: prod}` |
| `selector` | Labels do **recurso** | `matchLabels: {tier: "back*"}` |
| `annotations` | Annotations do recurso (wildcard) | `{owner: "?*"}` |
| `operations` | `CREATE`, `UPDATE`, `DELETE`, `CONNECT` | `[CREATE]` |

**Wildcards:** `*` = zero ou mais caracteres, `?` = exatamente um caractere.
`"?*"` = "pelo menos um caractere", ou seja, não vazio.

### Quem fez o request

| Campo | O que faz | Exemplo |
|---|---|---|
| `subjects` | Usuários, grupos ou ServiceAccounts | `[{kind: ServiceAccount, name: argocd-application-controller, namespace: argocd}]` |
| `roles` | Roles (namespaced) do usuário | — |
| `clusterRoles` | ClusterRoles do usuário | `[cluster-admin]` |

`kind` em `subjects`: `User`, `Group` ou `ServiceAccount`.

**Atenção:** filtrar por `subjects`, `roles` ou `clusterRoles` exige
`spec.background: false`. No background scan não existe request nem usuário.
Sem isso o Kyverno recusa a policy com:
`only select variables are allowed in background mode`.

## Exemplo completo (validado com `--dry-run=server`)
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: match-demo
spec:
  background: false              # obrigatório porque o exclude usa subjects
  rules:
    - name: match-demo
      match:
        any:
          - resources:           # Pods/Deployments em namespaces team-*
              kinds: [Pod, apps/v1/Deployment]
              namespaces: ["team-*"]
              operations: [CREATE, UPDATE]
          - resources:           # OU StatefulSets db-* do tier back*, em ns prod
              kinds: [StatefulSet]
              names: ["db-?*"]
              selector:
                matchLabels:
                  tier: "back*"
              namespaceSelector:
                matchLabels:
                  env: prod
      exclude:
        any:                     # ignora se veio do ArgoCD OU de um cluster-admin
          - subjects:
              - kind: ServiceAccount
                name: argocd-application-controller
                namespace: argocd
          - clusterRoles: [cluster-admin]
      validate:
        failureAction: Audit
        message: "A label 'env' é obrigatória."
        pattern:
          metadata:
            labels:
              env: "?*"
```

## Equivalência com as policies CEL

| ClusterPolicy (`match`) | Policy CEL (`matchConstraints`) |
|---|---|
| `kinds: [Pod]` | `resourceRules: [{apiGroups: [''], apiVersions: [v1], resources: [pods]}]` |
| `operations` | `resourceRules[].operations` |
| `names` | `resourceRules[].resourceNames` (sem wildcard) ou `matchConditions` com CEL |
| `namespaces: [x]` | `namespaceSelector` com `kubernetes.io/metadata.name` |
| `namespaceSelector` | `namespaceSelector` |
| `selector` | `objectSelector` |
| `annotations` | `matchConditions` (CEL em `object.metadata.annotations`) |
| `subjects` / `clusterRoles` | `matchConditions` com `request.userInfo` |
| `exclude` | `excludeResourceRules` + `matchConditions` |
| `any` | vários itens em `resourceRules` (já é OU) |
| `all` | combinar `matchConstraints` + `matchConditions` (tudo precisa bater) |
