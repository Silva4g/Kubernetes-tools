# Kubernetes-tools
Laboratório local para testar ferramentas do Kubernetes.

Cada pasta é uma ferramenta, com um README explicando o que é e como instalar:

- [kind](kind/README.md): cluster local configurado como kubeadm (comece por aqui)
- [kyverno](kyverno/README.md): testes de policy

## Pré-requisitos
`docker`, `kind`, `kubectl` e `helm`.

Atalho: `make up` sobe o cluster completo (veja [kind/README.md](kind/README.md#atalho-script)).
