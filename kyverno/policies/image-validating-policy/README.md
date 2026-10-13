# ImageValidatingPolicy
**O que é:** verifica a **cadeia de suprimentos** das imagens: assinatura
(cosign ou notary), attestations (SBOM, provenance SLSA, scan de
vulnerabilidade) e digest. Pode trocar a tag pelo digest no pod.

**Quando usar:**
- Só rodar imagens assinadas pelo seu CI (keyless via GitHub Actions/OIDC ou chave).
- Exigir SBOM ou provenance SLSA anexados.
- Bloquear imagens com CVE crítica a partir de uma attestation de scan.
- Fixar o digest (`mutateDigest`), para garantir que roda exatamente o que foi verificado.

**Quando não usar:** para checar só o **nome** da imagem (registry, tag), basta
uma ValidatingPolicy com `image()`. Ela é mais leve e não consulta o registry.

## Funções CEL específicas

| Função | O que faz |
|---|---|
| `images.containers` | Lista das imagens dos containers que bateram em `matchImageReferences` (também existem `images.initContainers` e `images.ephemeralContainers`) |
| `verifyImageSignatures(img, [attestors.x])` | Verifica a assinatura e devolve quantos attestors validaram (use `> 0`) |
| `verifyAttestationSignatures(img, attestations.x, [attestors.x])` | Verifica a assinatura de uma attestation |
| `extractPayload(img, attestations.x)` | Devolve o conteúdo da attestation (ex.: o SBOM) para validar campos. Precisa verificar antes |

Attestor com nome com `-`: use `attestors['meu-nome']`.

## Opções (`spec`)

| Campo | Tipo | O que faz |
|---|---|---|
| `matchImageReferences[]` | lista | Quais imagens verificar: `glob: 'ghcr.io/org/*'` ou `expression` (CEL). Imagem que não bate é **ignorada** |
| `attestors[]` | lista (obrigatório) | Quem é confiável. Cada um tem `name` + `cosign` **ou** `notary` |
| `attestations[]` | lista | Attestations a verificar: `name` + `intoto.type` (ex.: `https://cyclonedx.org/bom`) ou `referrer.type` (OCI 1.1) |
| `validations[]` | lista (obrigatório) | Regras CEL usando as funções acima |
| `validationActions` | `Deny` \| `Audit` \| `Warn` | Igual ao da ValidatingPolicy |
| `validationConfigurations.mutateDigest` | bool (`true`) | Troca `imagem:tag` por `imagem:tag@sha256:...` |
| `validationConfigurations.verifyDigest` | bool (`true`) | Exige que a imagem tenha digest |
| `validationConfigurations.required` | bool (`true`) | Exige que a imagem tenha passado por alguma verificação |
| `images[]` | lista `{name, expression}` | Extrai imagens de CRDs/JSON (para Pods é automático). Fica acessível em `images.<name>` |
| `credentials.providers` | `default`, `amazon`, `azure`, `google`, `github` | Autenticação no registry via cloud |
| `credentials.secrets` | lista | Secrets (no namespace do Kyverno) com credenciais do registry |
| `credentials.allowInsecureRegistry` | bool | Permite registry sem TLS |
| `matchConstraints`, `matchConditions`, `variables`, `auditAnnotations`, `failurePolicy`, `webhookConfiguration`, `autogen.podControllers` | | Iguais aos da ValidatingPolicy (aumente o timeout: verificar consulta o registry) |
| `evaluation.admission/background/mode` | | Iguais aos da ValidatingPolicy |

## Attestor `cosign`

| Campo | O que faz |
|---|---|
| `key.data` | Chave pública PEM inline |
| `key.kms` | Chave em KMS (`awskms://`, `gcpkms://`, `azurekms://`, `hashivault://`) |
| `key.expression` | CEL que devolve a chave (ex.: lida de um ConfigMap) |
| `key.hashAlgorithm` | `sha224`, `sha256` (padrão), `sha384`, `sha512` |
| `keyless.identities[]` | Assinatura sem chave (Fulcio/OIDC): `issuer`/`issuerRegExp` + `subject`/`subjectRegExp`/`subjectExpression` |
| `keyless.roots` | CAs raiz próprias (PEM) |
| `keyless.additionalExtensions` | Extensões do certificado que precisam bater (ex.: repositório, workflow do GitHub) |
| `certificate.cert` / `certChain` | Verificar com certificado próprio (`value` ou `expression`) |
| `ctlog.url` | Rekor próprio (padrão: `rekor.sigstore.dev`) |
| `ctlog.rekorPubKey` / `ctLogPubKey` | Chaves de um Rekor/CT log próprio |
| `ctlog.tsaCertChain` | Cadeia do Timestamp Authority (RFC3161), para imagens assinadas sem Rekor |
| `ctlog.insecureIgnoreTlog` | Não checa o transparency log (**só para lab**) |
| `ctlog.insecureIgnoreSCT` | Não checa o SCT do certificado |
| `source.repository` / `tagPrefix` / `PullSecrets` | Busca as assinaturas em outro repositório |
| `tuf.mirror` / `tuf.root` | Mirror TUF do Sigstore (ambientes air-gapped) |
| `trustedRoot` | `trusted_root.json` do Sigstore inline, em vez de buscar via TUF |
| `annotations` | Pares chave/valor que precisam existir no payload assinado |

## Attestor `notary`

| Campo | O que faz |
|---|---|
| `certs` | Cadeia de certificados para verificar a assinatura Notation (`value` ou `expression`) |
| `tsaCerts` | Cadeia do TSA para verificar o timestamp |

> Conceitos comuns (`matchConstraints`, `variables`, variáveis do CEL...): [../README.md](../README.md)

## Testar
```shell
kubectl apply -f kyverno/policies/image-validating-policy/policy.yaml
kubectl get imagevalidatingpolicies          # esperar READY=true
kubectl apply -f kyverno/policies/image-validating-policy/resources.yaml
```
Remover:
```shell
kubectl delete -f kyverno/policies/image-validating-policy/
```

## Pegadinhas
- O motivo real da falha só aparece no log do admission controller:
  `kubectl -n kyverno logs deploy/kyverno-admission-controller | grep "image verification failed"`
- A chave pública que aparece no log veio **junto com a assinatura**: não use ela sem conferir em uma fonte confiável (senão qualquer um assina e "prova").
- A imagem de teste foi assinada sem Rekor, então o exemplo usa `insecureIgnoreTlog: true` (só lab).
