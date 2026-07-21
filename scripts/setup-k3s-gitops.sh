#!/bin/bash

# Ensure script is run with bash (not sh) to avoid POSIX/builtin differences
if [ -z "${BASH_VERSION:-}" ]; then
    echo "This script requires bash. Run it with: bash $0 or ./$(basename \"$0\")"
    exit 1
fi

################################################################################
# 🚀 K3s + Argo CD + GitOps - Setup Automatizado
# 
# Uso:
#   ./setup-k3s-gitops.sh
#
# O script fará:
#   1. Instalar K3s
#   2. Instalar Argo CD
#   3. Criar namespaces
#   4. Configurar GitOps
################################################################################

set -e  # Exit on error

# ✅ Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ✅ Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# ✅ Progress bar
show_progress() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

################################################################################
# 1️⃣ Verificar Pré-requisitos
################################################################################

show_progress "Verificando Pré-requisitos"

# Verificar WSL2/Linux
if ! grep -i "microsoft" /proc/version &> /dev/null && [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "Script deve ser executado em WSL2 ou Linux"
    exit 1
fi

log_success "Sistema: Linux/WSL2 ✓"

# Verificar Docker (opcional - K3s tem containerd integrado)
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_success "Docker instalado: $DOCKER_VERSION ✓"
else
    log_warning "Docker não encontrado (opcional - K3s tem containerd integrado)"
fi

# Verificar Git
if ! command -v git &> /dev/null; then
    log_error "Git não encontrado. Instale git"
    exit 1
fi

log_success "Git instalado ✓"

# Verificar sudo
if ! sudo -n true 2>/dev/null; then
    log_warning "Sudo sem senha não configurado. Pode pedir senha durante instalação"
fi

################################################################################
# 2️⃣ Instalar K3s
################################################################################

show_progress "Instalando K3s"

if command -v k3s &> /dev/null; then
    log_warning "K3s já está instalado"
    K3S_VERSION=$(k3s --version)
    log_info "Versão: $K3S_VERSION"
else
    log_info "Baixando e instalando K3s..."
    
    # Download K3s
    curl -sfL https://get.k3s.io | sh -
    
    # Configurar permissões
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    
    # Exportar KUBECONFIG
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # Adicionar ao .bashrc
    if ! grep -q "KUBECONFIG=/etc/rancher/k3s/k3s.yaml" ~/.bashrc; then
        echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    fi
    
    log_success "K3s instalado com sucesso"
fi

# Aguardar K3s estar pronto
log_info "Aguardando K3s iniciar..."
sleep 5

# Verificar status
if sudo systemctl is-active --quiet k3s; then
    log_success "K3s está rodando"
else
    log_error "K3s não conseguiu iniciar"
    exit 1
fi

# Esperar nós ficarem ready
log_info "Aguardando nós ficarem ready..."
for i in {1..60}; do
    NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [ "$NODE_STATUS" == "True" ]; then
        log_success "Nó está ready"
        break
    fi
    echo -n "."
    sleep 2
    if [ $i -eq 60 ]; then
        log_error "Timeout aguardando nó ficar ready"
        exit 1
    fi
done
echo ""

################################################################################
# 3️⃣ Instalar kubectl
################################################################################

show_progress "Configurando kubectl"

if ! command -v kubectl &> /dev/null; then
    log_info "kubectl não encontrado, criando symlink..."
    sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl || true
fi

log_success "kubectl configurado"

# Verificar cluster
log_info "Informações do cluster:"
kubectl cluster-info
kubectl get nodes

################################################################################
# 4️⃣ Criar Namespaces
################################################################################

show_progress "Criando Namespaces"

log_info "Criando namespace 'fastapi'..."
kubectl create namespace fastapi --dry-run=client -o yaml | kubectl apply -f -

log_info "Namespace 'argocd' será criado pela instalação do Argo CD"

log_success "Namespaces criados"

################################################################################
# 5️⃣ Instalar Argo CD
################################################################################

show_progress "Instalando Argo CD"

if kubectl get namespace argocd &>/dev/null; then
    log_warning "Argo CD já pode estar instalado"
else
    log_info "Criando namespace argocd..."
    kubectl create namespace argocd
fi

log_info "Instalando manifests do Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "Aguardando pods do Argo CD ficarem ready (~2 minutos)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

log_success "Argo CD instalado"

################################################################################
# 6️⃣ Instalar Argo CD CLI
################################################################################

show_progress "Instalando Argo CD CLI"

if command -v argocd &> /dev/null; then
    ARGOCD_VERSION=$(argocd version --client | head -1)
    log_success "Argo CD CLI já está instalado: $ARGOCD_VERSION"
else
    log_info "Instalando Argo CD CLI..."
    
    # Detectar OS
    UNAME_S=$(uname -s)
    UNAME_M=$(uname -m)
    
    if [ "$UNAME_S" == "Linux" ]; then
        if [ "$UNAME_M" == "x86_64" ]; then
            BINARY="argocd-linux-amd64"
        else
            BINARY="argocd-linux-arm64"
        fi
    else
        log_error "Sistema não suportado"
        exit 1
    fi
    
    curl -sSL -o /tmp/$BINARY https://github.com/argoproj/argo-cd/releases/latest/download/$BINARY
    sudo install -m 555 /tmp/$BINARY /usr/local/bin/argocd
    rm /tmp/$BINARY
    
    log_success "Argo CD CLI instalado"
fi

################################################################################
# 7️⃣ Obter Senha do Argo CD
################################################################################

show_progress "Configuração do Argo CD"

log_info "Aguardando Argo CD estar completamente pronto..."
sleep 10

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "PENDENTE")

if [ "$ARGOCD_PASSWORD" != "PENDENTE" ]; then
    log_success "Credenciais do Argo CD:"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: $ARGOCD_PASSWORD${NC}"
    echo ""
    echo -e "${BLUE}Para acessar a UI, execute:${NC}"
    echo -e "${BLUE}  kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    echo -e "${BLUE}  Depois acesse: https://localhost:8080${NC}"
else
    log_warning "Não conseguiu obter senha inicial. Pode já ter sido alterada"
fi

################################################################################
# 8️⃣ Criar estrutura de diretórios
################################################################################

show_progress "Criando Estrutura de Diretórios"

log_info "Criando diretórios para manifests..."

mkdir -p kubernetes/{infrastructure,apps/fastapi-app,argocd,monitoring}

log_success "Diretórios criados em: kubernetes/"

################################################################################
# 9️⃣ Resumo Final
################################################################################

show_progress "Setup Completo! ✅"

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          K3s + Argo CD + GitOps - Pronto!                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}📊 Próximos Passos:${NC}"
echo ""
echo "1️⃣  Acessar Argo CD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   URL: https://localhost:8080"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "2️⃣  Criar Repositório GitOps:"
echo "   - Push dos arquivos YAML para GitHub"
echo "   - Conectar repositório no Argo CD"
echo ""
echo "3️⃣  Deploy FastAPI:"
echo "   - Copiar deployment.yaml para kubernetes/apps/fastapi-app/"
echo "   - Criar Application no Argo CD"
echo ""
echo "4️⃣  Testar:"
echo "   kubectl port-forward svc/fastapi-app 8000:80 -n fastapi"
echo "   curl http://localhost:8000/"
echo ""
echo -e "${BLUE}📚 Documentação:${NC}"
echo "   - K3S_GITOPS_SETUP.md - Guia completo"
echo "   - K3S_QUICK_REFERENCE.md - Comandos úteis"
echo ""
echo -e "${YELLOW}⚠️  Comandos Úteis:${NC}"
echo "   kubectl get all -n fastapi"
echo "   argocd app list"
echo "   argocd app get fastapi-app"
echo ""
echo -e "${GREEN}✅ Setup finalizado com sucesso!${NC}"
echo ""
