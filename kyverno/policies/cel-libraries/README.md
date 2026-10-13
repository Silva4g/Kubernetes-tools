# CEL Libraries
Funções que o Kyverno **adiciona** ao CEL padrão do Kubernetes. Funcionam em
qualquer policy CEL. Exemplo testado no `policy.yaml` desta pasta.

| Library | Funções | Quando usar |
|---|---|---|
| **Resource** | `resource.Get(apiVersion, recurso, ns, nome)`, `resource.List(apiVersion, recurso, ns)`, `resource.Post(apiVersion, recurso, body)` | Ler config do cluster (ConfigMap com lista permitida), checar se algo existe, clonar na GeneratingPolicy. `Post` cria, por exemplo, um `SubjectAccessReview` |
| **HTTP** | `http.Get(url)`, `http.Post(url, body, headers)`, `http.Client(caBundle).Get(url)` | Consultar uma API externa (CMDB, aprovação, feature flag). Aumente o timeout |
| **GlobalContext** | `globalContext.Get(nome, path)` | Ler dados cacheados por um `GlobalContextEntry` (mais barato que `resource.List` a cada request) |
| **User** | `parseServiceAccount(username)` → `.Namespace`, `.Name` | Regras por ServiceAccount (`system:serviceaccount:<ns>:<nome>`) |
| **Image** | `image(ref)` → `.registry()`, `.repository()`, `.tag()`, `.digest()`, `.identifier()`, `.containsDigest()`; `isImage(ref)` | Validar registry/tag sem consultar o registry. `image("nginx").registry()` = `index.docker.io` |
| **ImageData** | `image.GetMetadata(ref)` → `.config`, `.manifest`, `.digest` | Ler metadados reais da imagem no registry (arquitetura, labels, usuário) |
| **Generator** | `generator.Apply(ns, [recursos])` | Só na GeneratingPolicy |
| **JSON** | `json.unmarshal(string)` | Transformar uma string JSON (anotação, ConfigMap) em objeto |
| **YAML** | `yaml.parse(string)` | Igual ao JSON, para YAML |
| **Time** | `time.now()`, `time.truncate(ts, duração)`, `time.toCron(ts)` | TTL, janelas de horário ("sem deploy na sexta"). Combine com `timestamp()` e `duration()` do CEL |
| **X509** | `x509.decode(pem)` → `.NotAfter`, `.Subject`... | Validar certificado em Secret (validade, CN) |
| **Hash** | `md5(v)`, `sha1(v)`, `sha256(v)` | Gerar nomes/labels determinísticos, comparar conteúdo |
| **Math** | `math.round(valor, casas)` | Arredondar cálculos (custo, porcentagem) |
| **Random** | `random(padrão)` (padrão `[0-9a-z]{8}`) | Sufixo aleatório para nomes gerados |
| **Transform** | `listObjToMap(chaves, valores, campoChave, campoValor)` | Transformar duas listas em um map |

Além disso, valem todas as funções nativas do CEL do Kubernetes: `has()`,
`all()`, `exists()`, `filter()`, `map()`, `matches()` (regex), `startsWith()`,
`split()`, `join()`, `quantity()`, `url()`, `ip()`/`cidr()`, campos opcionais
(`object.?spec.?foo.orValue(x)`, `map[?'chave']`) etc.

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/cel-libraries/policy.yaml
kubectl get validatingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/cel-libraries/resources.yaml
```
Remover:
```shell
kubectl delete -f kyverno/policies/cel-libraries/
```

## Pegadinhas
- `image("nginx").registry()` devolve `index.docker.io`, não `docker.io`.
- `resource.Get` usa a permissão do Kyverno: ele precisa de RBAC para ler o recurso.
