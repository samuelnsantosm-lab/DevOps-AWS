# 🚀 Guia de Setup - K3s + Argo CD + GitOps

## 📋 Resumo

Este diretório contém tudo o que você precisa para rodar K3s (Kubernetes leve) com Argo CD (GitOps) no WSL2.

## 📁 Estrutura de Arquivos

```
DevOps-AWS/
├── K3S_GITOPS_SETUP.md          ← Guia completo e detalhado
├── K3S_QUICK_REFERENCE.md       ← Referência rápida com comandos
├── scripts/
│   └── setup-k3s-gitops.sh      ← Script de setup automatizado
└── kubernetes/
    ├── infrastructure/          ← Namespaces, RBAC, Storage
    ├── apps/
    │   └── fastapi-app/         ← Manifests da aplicação
    └── argocd/                  ← Configuração Argo CD
```

## ⚡ Quick Start (3 Passos)

### Passo 1: Executar Script de Setup

```bash
# Entrar no diretório do projeto
cd ~/DevOps-AWS

# Dar permissão de execução
chmod +x scripts/setup-k3s-gitops.sh

# Executar setup (levará ~5-10 minutos)
./scripts/setup-k3s-gitops.sh
```

**O que o script faz:**
- ✅ Instala K3s
- ✅ Instala Argo CD
- ✅ Cria namespaces
- ✅ Configura kubectl
- ✅ Exibe credenciais

### Passo 2: Acessar Argo CD

```bash
# Terminal 1: Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Terminal 2: Acessar
# URL: https://localhost:8080
# Username: admin
# Password: (da saída do script)

# ⚠️ Aceitar certificado auto-assinado no navegador
```

### Passo 3: Deploy FastAPI

```bash
# Aplicar namespaces
kubectl apply -f kubernetes/infrastructure/namespaces.yaml

# Aplicar deployment
kubectl apply -f kubernetes/apps/fastapi-app/

# Verificar pods
kubectl get pods -n fastapi

# Port-forward para testar
kubectl port-forward svc/fastapi-app 8000:80 -n fastapi

# Testar
curl http://localhost:8000/
```

---

## 🔄 Fluxo Completo Passo a Passo

### 1️⃣ Setup K3s + Argo CD

```bash
# Entrar em WSL2 (se estiver em Windows)
wsl

# Clonar/navegar para projeto
cd ~/DevOps-AWS

# Executar setup
chmod +x scripts/setup-k3s-gitops.sh
./scripts/setup-k3s-gitops.sh

# Saída esperada:
# ✅ K3s instalado
# ✅ Argo CD instalado
# ✅ Credenciais exibidas
```

### 2️⃣ Verificar Instalação

```bash
# Terminal novo
kubectl get all -n kube-system          # Ver componentes K8s
kubectl get all -n argocd               # Ver Argo CD
kubectl get nodes                        # Ver nós
kubectl cluster-info                     # Info do cluster
```

### 3️⃣ Criar Repositório GitOps (GitHub)

```bash
# 1. Criar repositório no GitHub: devops-k3s-gitops

# 2. Clonar
git clone https://github.com/seu-usuario/devops-k3s-gitops.git
cd devops-k3s-gitops

# 3. Copiar estrutura kubernetes/
cp -r ~/DevOps-AWS/kubernetes . 

# 4. Commit
git add .
git commit -m "Initial commit: K3s manifests"
git push origin main
```

### 4️⃣ Conectar Git ao Argo CD

```bash
# Via CLI
argocd repo add https://github.com/seu-usuario/devops-k3s-gitops.git \
  --username seu-usuario-github \
  --password seu-token-github

# Verificar
argocd repo list

# Ou via UI:
# Argo CD → Settings → Repositories → Connect Repo
```

### 5️⃣ Criar Application

```bash
# Opção 1: Via arquivo YAML
kubectl apply -f kubernetes/argocd/application.yaml

# Opção 2: Via CLI
argocd app create fastapi-app \
  --repo https://github.com/seu-usuario/devops-k3s-gitops.git \
  --path kubernetes/apps/fastapi-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace fastapi

# Opção 3: Via UI
# Argo CD → Applications → New App
```

### 6️⃣ Deploy da Aplicação

```bash
# Sincronizar (fazer deploy)
argocd app sync fastapi-app

# Aguardar sync
kubectl rollout status deployment/fastapi-app -n fastapi

# Verificar pods
kubectl get pods -n fastapi

# Testar
kubectl port-forward svc/fastapi-app 8000:80 -n fastapi
curl http://localhost:8000/
```

### 7️⃣ Validar GitOps (Fazer Mudança)

```bash
# No repositório Git
cd devops-k3s-gitops

# Editar replicas
vi kubernetes/apps/fastapi-app/deployment.yaml
# Mudar: replicas: 2 → replicas: 3

# Commit
git add .
git commit -m "chore: scale to 3 replicas"
git push origin main

# Argo CD detecta (webhooks) ou aguarda polling
# Pods aumentam de 2 para 3 automaticamente!

# Verificar
kubectl get pods -n fastapi -w
argocd app get fastapi-app
```

---

## 🔧 Comandos Úteis

### Kubectl

```bash
# Verificar status
kubectl get nodes
kubectl get pods -n fastapi
kubectl get deployments -n fastapi
kubectl get svc -n fastapi

# Logs e debugging
kubectl logs -n fastapi -l app=fastapi-app -f
kubectl describe pod <pod-name> -n fastapi
kubectl exec -it <pod-name> -n fastapi -- bash

# Escalar
kubectl scale deployment fastapi-app --replicas=5 -n fastapi

# Port-forward
kubectl port-forward svc/fastapi-app 8000:80 -n fastapi

# Deletar
kubectl delete deployment fastapi-app -n fastapi
```

### Argo CD

```bash
# Ver status
argocd app list
argocd app get fastapi-app
argocd app get fastapi-app --refresh

# Sincronizar
argocd app sync fastapi-app
argocd app sync fastapi-app --prune

# Gerenciar repositórios
argocd repo list
argocd repo add https://...

# Credenciais
argocd account update-password
```

---

## 🐛 Troubleshooting

### ❌ K3s não inicia

```bash
# Verificar status
sudo systemctl status k3s

# Reiniciar
sudo systemctl restart k3s

# Ver logs
sudo journalctl -u k3s -f
```

### ❌ Argo CD UI não acessível

```bash
# Verificar pods
kubectl get pods -n argocd

# Verificar port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acessar
# https://localhost:8080
# (aceitar certificado auto-assinado)
```

### ❌ Pod em CrashLoopBackOff

```bash
# Ver logs
kubectl logs -n fastapi <pod-name>

# Descrever
kubectl describe pod -n fastapi <pod-name>

# Verificar image
kubectl describe deployment -n fastapi fastapi-app | grep -i image
```

### ❌ Git sync falha

```bash
# Verificar credenciais
argocd repo list

# Verificar manifests
kubectl apply -f kubernetes/apps/fastapi-app/ --dry-run=client

# Ver logs do Argo CD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

---

## 📚 Documentação Detalhada

Para guias mais completos, veja:

| 📖 Arquivo | 📝 Conteúdo |
|---|---|
| **K3S_GITOPS_SETUP.md** | Guia passo a passo completo |
| **K3S_QUICK_REFERENCE.md** | Referência rápida com todos os comandos |
| **kubernetes/** | Exemplos de manifests YAML |

---

## 🚀 Próximos Passos

Depois do setup inicial:

1. **CI/CD**: Integrar com GitHub Actions para auto-build e push
2. **Monitoring**: Adicionar Prometheus + Grafana
3. **Ingress**: Configurar HTTPS com Let's Encrypt
4. **Backup**: Automatizar backups do estado
5. **Multi-env**: Adicionar staging e production

---

## ⚡ Performance Tips

```bash
# Aumentar resources do K3s
export K3S_OPTS="--kubelet-arg=--max-pods=250"

# Aumentar Docker memory (se usar Docker Desktop)
# Settings → Resources → Memory: 4GB+

# Usar SSD para melhor performance
# K3s usa etcd, SSD melhora latência
```

---

## 📞 Suporte

Tem dúvidas?

1. 📖 Leia **K3S_GITOPS_SETUP.md**
2. ⚡ Consulte **K3S_QUICK_REFERENCE.md**
3. 🔍 Busque no troubleshooting acima
4. 📞 Abra uma issue no GitHub

---

**Última atualização**: Julho 2024  
**Testado em**: WSL2 + Ubuntu 22.04 + K3s 1.27+ + Argo CD 2.6+  
**Status**: ✅ Pronto para uso
