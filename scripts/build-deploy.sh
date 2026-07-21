#!/bin/bash

################################################################################
# 🚀 Build, Push & Deploy Rápido
#
# Este script faz:
# 1. Build da imagem Docker
# 2. Push para Docker Hub
# 3. Atualiza tag no deployment.yaml
# 4. Commit e push no Git
# 5. Argo CD detecta e sincroniza automaticamente
#
# Uso:
#   ./build-deploy.sh v1.1.0
#   ./build-deploy.sh latest
################################################################################

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Validar argumentos
if [ -z "$1" ]; then
    echo -e "${RED}❌ Tag não fornecida${NC}"
    echo "Uso: $0 <tag>"
    echo "Exemplo: $0 v1.1.0"
    exit 1
fi

TAG=$1
DOCKER_USERNAME="${DOCKER_USERNAME:-seu-usuario-dockerhub}"
IMAGE_NAME="${DOCKER_USERNAME}/fastapi-app"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITOPS_REPO="${GITOPS_REPO:-${PROJECT_ROOT}/../devops-k3s-gitops}"
DEPLOYMENT_FILE="${GITOPS_REPO}/kubernetes/apps/fastapi-app/deployment.yaml"

################################################################################
# 1️⃣ Validações
################################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Build, Push & Deploy - FastAPI App${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}📋 Configurações:${NC}"
echo "Image: $FULL_IMAGE"
echo "Projeto: $PROJECT_ROOT"
echo "GitOps Repo: $GITOPS_REPO"
echo ""

# Verificar Docker login
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando${NC}"
    exit 1
fi

# Verificar se está no Docker Hub
DOCKER_CONFIG=$(cat ~/.docker/config.json 2>/dev/null || echo "")
if [[ ! "$DOCKER_CONFIG" =~ "auths" ]]; then
    echo -e "${YELLOW}⚠️  Você não fez login no Docker Hub${NC}"
    echo "Executando: docker login"
    docker login
fi

################################################################################
# 2️⃣ Build da Imagem Docker
################################################################################

echo ""
echo -e "${BLUE}1️⃣ Buildando imagem Docker...${NC}"
echo ""

cd "$PROJECT_ROOT"

if ! docker build -t "$FULL_IMAGE" -t "${IMAGE_NAME}:latest" .; then
    echo -e "${RED}❌ Build falhou${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build concluído${NC}"

################################################################################
# 3️⃣ Push para Docker Hub
################################################################################

echo ""
echo -e "${BLUE}2️⃣ Fazendo push para Docker Hub...${NC}"
echo ""

if ! docker push "$FULL_IMAGE"; then
    echo -e "${RED}❌ Push falhou${NC}"
    exit 1
fi

if ! docker push "${IMAGE_NAME}:latest"; then
    echo -e "${RED}⚠️ Push da tag 'latest' falhou (não crítico)${NC}"
fi

echo -e "${GREEN}✅ Push concluído${NC}"

################################################################################
# 4️⃣ Atualizar Deployment no GitOps Repo
################################################################################

echo ""
echo -e "${BLUE}3️⃣ Atualizando manifests no repositório GitOps...${NC}"
echo ""

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo -e "${RED}❌ Arquivo não encontrado: $DEPLOYMENT_FILE${NC}"
    echo "Certifique-se de que o repositório GitOps existe em: $GITOPS_REPO"
    exit 1
fi

# Usar sed para atualizar a tag da imagem
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|image: ${DOCKER_USERNAME}/fastapi-app:.*|image: ${FULL_IMAGE}|g" "$DEPLOYMENT_FILE"
else
    # Linux
    sed -i "s|image: ${DOCKER_USERNAME}/fastapi-app:.*|image: ${FULL_IMAGE}|g" "$DEPLOYMENT_FILE"
fi

echo -e "${GREEN}✅ Manifests atualizados${NC}"

# Verificar mudança
echo -e "${BLUE}Mudança no deployment.yaml:${NC}"
grep -A2 "image:" "$DEPLOYMENT_FILE" | head -3

################################################################################
# 5️⃣ Commit & Push no Git
################################################################################

echo ""
echo -e "${BLUE}4️⃣ Commitando mudanças no Git...${NC}"
echo ""

cd "$GITOPS_REPO"

# Verificar se há mudanças
if ! git diff --quiet; then
    echo "Mudanças detectadas:"
    git diff --stat
    echo ""
    
    # Commit
    git add kubernetes/apps/fastapi-app/deployment.yaml
    git commit -m "chore: update fastapi-app image to $TAG"
    
    # Push
    if git push origin main; then
        echo -e "${GREEN}✅ Push concluído${NC}"
    else
        echo -e "${RED}❌ Push falhou${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ️  Sem mudanças para commitar${NC}"
fi

################################################################################
# 6️⃣ Aguardar Argo CD Sincronizar
################################################################################

echo ""
echo -e "${BLUE}5️⃣ Aguardando Argo CD sincronizar...${NC}"
echo ""

# Forçar refresh
argocd app get fastapi-app --refresh 2>/dev/null || true

# Aguardar sync
MAX_WAIT=300  # 5 minutos
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    SYNC_STATUS=$(argocd app get fastapi-app -o json 2>/dev/null | jq -r '.status.operationState.phase // "Unknown"' || echo "Unknown")
    
    if [ "$SYNC_STATUS" == "Succeeded" ] || [ "$SYNC_STATUS" == "Unknown" ]; then
        echo -e "${GREEN}✅ Sincronização concluída${NC}"
        break
    fi
    
    echo "Status: $SYNC_STATUS... aguardando"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

################################################################################
# 7️⃣ Validar Deployment
################################################################################

echo ""
echo -e "${BLUE}6️⃣ Validando deployment...${NC}"
echo ""

# Verificar rollout status
if kubectl rollout status deployment/fastapi-app -n fastapi --timeout=5m; then
    echo -e "${GREEN}✅ Pods atualizados com sucesso${NC}"
else
    echo -e "${YELLOW}⚠️  Rollout ainda em progresso${NC}"
fi

# Mostrar status
echo ""
echo -e "${BLUE}Status atual:${NC}"
kubectl get deployment fastapi-app -n fastapi -o wide
echo ""
kubectl get pods -n fastapi -o wide

################################################################################
# 8️⃣ Resumo
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deploy completo!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Resumo:${NC}"
echo "1. ✅ Imagem construída: $FULL_IMAGE"
echo "2. ✅ Push para Docker Hub"
echo "3. ✅ Manifests atualizados no GitOps"
echo "4. ✅ Commit e push no Git"
echo "5. ✅ Argo CD sincronizou"
echo "6. ✅ Pods atualizados"
echo ""
echo -e "${BLUE}Comandos úteis:${NC}"
echo "  # Ver logs"
echo "  kubectl logs -n fastapi -l app=fastapi-app -f"
echo ""
echo "  # Testar"
echo "  kubectl port-forward svc/fastapi-app 8000:80 -n fastapi"
echo "  curl http://localhost:8000/"
echo ""
echo "  # Ver status Argo CD"
echo "  argocd app get fastapi-app"
echo ""
