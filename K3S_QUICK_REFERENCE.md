# 🚀 Referência Rápida - K3s + Argo CD + GitOps

## ⚡ Comandos Essenciais do Kubectl

```bash
# 📋 Cluster Info
kubectl cluster-info
kubectl get nodes
kubectl get all --all-namespaces
kubectl top nodes                    # Resource usage

# 📦 Deployment Management
kubectl get deployments -n fastapi
kubectl describe deployment fastapi-app -n fastapi
kubectl scale deployment fastapi-app --replicas=3 -n fastapi
kubectl rollout status deployment/fastapi-app -n fastapi
kubectl rollout history deployment/fastapi-app -n fastapi
kubectl rollout undo deployment/fastapi-app -n fastapi   # Voltar versão anterior

# 🐳 Pod Management
kubectl get pods -n fastapi
kubectl logs <pod-name> -n fastapi
kubectl logs <pod-name> -n fastapi -f               # Follow logs
kubectl exec -it <pod-name> -n fastapi -- bash     # Entrar no pod
kubectl describe pod <pod-name> -n fastapi
kubectl port-forward <pod-name> 8000:8000 -n fastapi

# 🌐 Service & Networking
kubectl get svc -n fastapi
kubectl get ingress -n fastapi
kubectl describe ingress fastapi-app -n fastapi
kubectl port-forward svc/fastapi-app 8000:80 -n fastapi

# 🔄 Apply & Delete
kubectl apply -f deployment.yaml
kubectl apply -f . --recursive              # Aplicar tudo em diretório
kubectl delete -f deployment.yaml
kubectl delete deployment fastapi-app -n fastapi

# 📊 Monitoramento
kubectl get events -n fastapi --sort-by='.lastTimestamp'
kubectl top pods -n fastapi
kubectl get hpa -n fastapi
kubectl describe hpa fastapi-app -n fastapi

# 🔐 Secrets & ConfigMaps
kubectl get secrets -n fastapi
kubectl get configmaps -n fastapi
kubectl create secret generic my-secret --from-literal=key=value
kubectl create configmap my-config --from-file=config.yaml
```

---

## 🔄 Comandos Argo CD

```bash
# 📋 Status da Application
argocd app list
argocd app get fastapi-app
argocd app get fastapi-app --refresh       # Forçar refresh

# 🔄 Sincronização Manual
argocd app sync fastapi-app
argocd app sync fastapi-app --prune        # Deletar recursos extras
argocd app sync fastapi-app --force        # Forçar sync

# 📊 Monitoramento
argocd app wait fastapi-app                # Aguardar sync
argocd app diff fastapi-app                # Mostrar diferenças
argocd app logs fastapi-app                # Ver logs de sincronização

# 🔐 Credentials
argocd repo list
argocd repo add https://github.com/...
argocd account update-password             # Alterar senha admin

# ⚙️ Configurações
argocd cluster list
argocd project list
argocd account list
```

---

## 📚 Kubectl Aliases (Adicionar ao ~/.bashrc)

```bash
# Shortcuts
alias k=kubectl
alias kn='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployment'
alias kgs='kubectl get svc'
alias kgi='kubectl get ingress'
alias kdel='kubectl delete'
alias klogs='kubectl logs'
alias kexec='kubectl exec -it'
alias kctx='kubectl config current-context'
alias kshow='kubectl explain'

# Watch com intervalo customizado
function kwatch() {
  watch -n 1 kubectl get $@
}

# Rápido port-forward
function kpf() {
  kubectl port-forward $1 $2:$3 -n ${4:-default}
}

# Ver logs em tempo real
function klogs() {
  kubectl logs -f $1 -n ${2:-default}
}

# Executar comando em pod
function kexec() {
  kubectl exec -it $1 -n ${2:-default} -- ${3:-bash}
}
```

---

## 📁 Estrutura Git Recomendada

```
devops-k3s-gitops/
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml              # Build & Push Docker
│       └── deploy.yml          # Deploy via GitOps
├── kubernetes/
│   ├── infrastructure/
│   │   ├── namespaces.yaml
│   │   ├── rbac.yaml
│   │   └── storage.yaml
│   ├── apps/
│   │   └── fastapi-app/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── configmap.yaml
│   │       └── kustomization.yaml (opcional)
│   ├── argocd/
│   │   ├── application.yaml
│   │   ├── appproject.yaml
│   │   └── notifications.yaml
│   └── monitoring/
│       ├── prometheus.yaml
│       └── grafana.yaml
├── docker/
│   └── Dockerfile
├── scripts/
│   ├── setup-k3s.sh
│   ├── install-argocd.sh
│   └── setup-gitops.sh
└── README.md
```

---

## 🔄 Workflow GitOps Típico

### 1️⃣ Atualizar Código

```bash
# Editar código
cd ~/devops-aws
vi main.py

# Build e push imagem
docker build -t seu-usuario/fastapi-app:v2.0 .
docker push seu-usuario/fastapi-app:v2.0
```

### 2️⃣ Atualizar Manifests

```bash
# Clone do repositório GitOps
cd ~/devops-k3s-gitops

# Editar tag de imagem
vi kubernetes/apps/fastapi-app/deployment.yaml
# Mudar: image: seu-usuario/fastapi-app:v2.0

# Commit
git add kubernetes/
git commit -m "chore: update fastapi-app to v2.0"
git push origin main
```

### 3️⃣ Argo CD Detecta e Sincroniza

```bash
# Aguardar webhook (automático) ou forçar refresh
argocd app sync fastapi-app

# Ver status
argocd app get fastapi-app

# Monitorar rollout
kubectl rollout status deployment/fastapi-app -n fastapi
```

### 4️⃣ Validar Deployment

```bash
# Verificar pods
kubectl get pods -n fastapi

# Testar endpoint
curl http://localhost:8000/

# Ver logs
kubectl logs -f deployment/fastapi-app -n fastapi
```

---

## 🐛 Troubleshooting Rápido

```bash
# ❌ Pod em CrashLoopBackOff
kubectl logs <pod-name> -n fastapi
kubectl describe pod <pod-name> -n fastapi

# ❌ Image pull error
kubectl get events -n fastapi
# Verificar: Docker Hub credentials, image name, registry access

# ❌ Service não alcançável
kubectl port-forward svc/fastapi-app 8000:80 -n fastapi
# Verificar: service selector, endpoints

# ❌ Argo CD não faz sync
argocd app get fastapi-app --refresh
argocd app logs fastapi-app
# Verificar: git repository access, manifests validity

# ❌ Falta de recursos
kubectl top pods -n fastapi
kubectl top nodes
# Aumentar requests/limits ou adicionar nós

# ❌ Network Policy bloqueando
kubectl get networkpolicies -n fastapi
kubectl describe networkpolicy <name> -n fastapi
```

---

## 📊 Monitoramento Com K9s (TUI)

```bash
# Instalar
# Linux/WSL:
wget https://github.com/derailed/k9s/releases/download/v0.27.0/k9s_Linux_amd64.tar.gz
tar xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# Executar
k9s -n fastapi

# Atalhos úteis:
# :pods           - Listar pods
# :deploy         - Listar deployments
# :svc            - Listar services
# :logs           - Ver logs
# :describe       - Descrever recurso
# :delete         - Deletar recurso
# :port-forward   - Port forward
# :help           - Ajuda
```

---

## 🌐 Adicionar Hosts Local (Para Acessar via Nome)

### Windows (WSL2):

```bash
# Editar /etc/hosts (WSL)
sudo nano /etc/hosts

# Adicionar:
127.0.0.1 fastapi-app.local
127.0.0.1 api.local

# Salvar: Ctrl+O, Enter, Ctrl+X
```

### Windows PowerShell (Host):

```powershell
# Editar C:\Windows\System32\drivers\etc\hosts (como admin)
notepad C:\Windows\System32\drivers\etc\hosts

# Adicionar:
127.0.0.1 fastapi-app.local
127.0.0.1 api.local
```

Depois:
```bash
curl http://fastapi-app.local/
```

---

## 🔄 Sincronização Manual de Um Arquivo

```bash
# Se quiser aplicar um arquivo específico sem Git
kubectl apply -f kubernetes/apps/fastapi-app/deployment.yaml

# Ou via Kustomize
kubectl apply -k kubernetes/apps/fastapi-app/
```

---

## 📈 Aumentar/Diminuir Réplicas

```bash
# Via kubectl (manual)
kubectl scale deployment fastapi-app --replicas=5 -n fastapi

# Via Git (GitOps - recomendado)
# Editar deployment.yaml: replicas: 5
# git push
# Argo CD auto-sincroniza
```

---

## 🗑️ Limpar Resources

```bash
# Deletar tudo de um namespace
kubectl delete all --all -n fastapi

# Deletar namespace (e tudo dentro)
kubectl delete namespace fastapi

# Resetar K3s (CUIDADO!)
sudo /usr/local/bin/k3s-uninstall.sh
```

---

## 💡 Tips & Tricks

```bash
# Autocomplete kubectl
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Vim como editor padrão
export EDITOR=vim

# Buscar por logs de erro
kubectl logs -n fastapi -l app=fastapi-app | grep -i error

# Exportar manifests de um deployment
kubectl get deployment fastapi-app -n fastapi -o yaml > backup.yaml

# Converter entre YAML e JSON
kubectl get deployment -o json | jq '.items[0]'
```

---

**Última atualização**: Julho 2024
**Compatível com**: K3s 1.24+, Argo CD 2.6+
