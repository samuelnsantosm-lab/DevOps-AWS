# 🚀 DevOps-AWS

> **Infraestrutura em Nuvem Completa com Terraform, Docker e AWS**

![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-ECS%20|%20Fargate%20|%20ALB-FF9900?logo=amazon-aws&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Multi--Stage-2496ED?logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-FastAPI-3776AB?logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📋 Visão Geral

Este repositório demonstra um **fluxo profissional de deploy** na AWS usando Infrastructure as Code (IaC) com Terraform e containerização Docker.

| 🏗️ Componente | 📦 Tecnologia | ✨ Função |
|---|---|---|
| **Aplicação** | Python + FastAPI | API REST escalável |
| **Containerização** | Docker Multi-stage | Imagem leve e segura |
| **Orquestração** | ECS Fargate | Serverless container management |
| **Balanceamento** | Application Load Balancer | Distribuição de tráfego |
| **Rede** | VPC Multi-AZ | Isolamento e alta disponibilidade |
| **Segurança** | Security Groups | Firewall configurável |
| **IaC** | Terraform | Automação de infraestrutura |

---

## 🎯 Arquitetura em Camadas

```mermaid
graph TB
    subgraph "🌍 INTERNET"
        User["👤 Usuário Externo"]
    end
    
    subgraph "AWS Cloud"
        subgraph "📡 Camada Pública"
            IGW["🌐 Internet Gateway"]
            ALB["⚖️ Application Load Balancer<br/>Porta 80 HTTP"]
        end
        
        subgraph "🔒 Camada Privada - AZ-a"
            Task1["📦 Container 1<br/>Porta 8000<br/>10.0.3.x"]
        end
        
        subgraph "🔒 Camada Privada - AZ-b"
            Task2["📦 Container 2<br/>Porta 8000<br/>10.0.4.x"]
        end
        
        CloudWatch["📊 CloudWatch Logs<br/>/ecs/fastapi-app"]
    end
    
    User -->|HTTP:80| IGW
    IGW -->|Route| ALB
    ALB -->|Balancea| Task1
    ALB -->|Balancea| Task2
    Task1 -->|Log Stream| CloudWatch
    Task2 -->|Log Stream| CloudWatch
    
    style User fill:#90EE90
    style IGW fill:#FFB6C1
    style ALB fill:#FFB6C1
    style Task1 fill:#87CEEB
    style Task2 fill:#87CEEB
    style CloudWatch fill:#FFD700
```

---

## 📂 Estrutura do Repositório

```
DevOps-AWS/
├── 📄 main.py                      ← Aplicação FastAPI
├── 🐳 Dockerfile                   ← Build Multi-stage
├── 📖 README.md                    ← Este arquivo
└── 🏗️ Terraform/
    ├── 🌐 network.tf               ← VPC, Subnets, NAT Gateway
    ├── 🔒 security.tf              ← Security Groups
    ├── ⚙️ ecs.tf                    ← ECS, Fargate, Task Definition
    ├── ⚖️ alb.tf                    ← Application Load Balancer
    ├── 📋 providers.tf             ← Configuração AWS
    ├── 📝 variables.tf             ← Variáveis customizáveis
    ├── 📤 outputs.tf               ← Saídas (DNS ALB, etc)
    └── 💾 terraform.tfstate        ← Estado (gerado)
```

---

## 🎓 Guia Passo a Passo - Como o Projeto Funciona

### 1️⃣ **A Aplicação Python** (`main.py`)

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "healthy", "message": "API rodando com sucesso!"}
```

**O que faz:**
- 📡 Uma **API REST simples** construída com FastAPI
- 📨 Endpoint GET `/` retorna JSON com status da aplicação
- 🔌 Roda na porta **8000** dentro do container
- 📈 Escalável para adicionar mais endpoints

**Resposta Esperada:**
```json
{
  "status": "healthy",
  "message": "API rodando com sucesso!"
}
```

---

### 2️⃣ **Containerização** (`Dockerfile`) - Multi-stage Build 🐳

```mermaid
graph LR
    A["📥 Python 3.11-slim<br/>Stage: Builder"] -->|Instala FastAPI<br/>Uvicorn| B["🔧 Venv com<br/>Dependências"]
    B -->|Copia venv| C["📤 Python 3.11-slim<br/>Stage: Runner"]
    C -->|Cria usuário<br/>não-root| D["🔒 appuser<br/>UID: 10001"]
    D -->|Copia main.py<br/>com ownership| E["✅ Imagem Final<br/>50% menor<br/>Mais segura"]
```

**Estágio 1 - Builder (Compilação)** 🔨
- Instala Python 3.11, ferramentas de build
- Cria ambiente virtual (`/opt/venv`)
- Instala FastAPI e Uvicorn
- **Descartado** ao final (não fica na imagem final)

**Estágio 2 - Runner (Execução)** 🎯
- Copia **apenas** o venv do Builder (reduz tamanho 50%)
- Cria usuário não-root `appuser` (segurança)
- Copia `main.py` com ownership correto
- Executa com usuário sem privilégios

**Benefícios:**
| Aspecto | Ganho |
|--------|-------|
| 📦 **Tamanho** | 50% menor (sem ferramentas de build) |
| 🔒 **Segurança** | Sem privilégios root |
| ⚡ **Performance** | Build cache otimizado |
| 🔄 **CI/CD** | Deploy mais rápido |

---

### 3️⃣ **Infraestrutura AWS (Terraform)** ☁️

#### 📋 Configuração Inicial (`providers.tf`)
- Define que usamos o **provedor AWS** versão 5.x
- Região padrão: `us-east-1` (configurável em `variables.tf`)

#### 🌐 Arquitetura de Rede (`network.tf`)

```mermaid
graph TB
    subgraph "VPC: 10.0.0.0/16 - Virtual Private Cloud"
        IGW["🌐 Internet Gateway<br/>Entrada de tráfego"]
        
        subgraph "📍 Zona de Disponibilidade A"
            PubA["🟢 Subnet Pública AZ-a<br/>10.0.1.0/24<br/>ALB aqui"]
            PrivA["🔵 Subnet Privada AZ-a<br/>10.0.3.0/24<br/>ECS/Fargate"]
            RT_PubA["🔀 Route Table Pública"]
        end
        
        subgraph "📍 Zona de Disponibilidade B"
            PubB["🟢 Subnet Pública AZ-b<br/>10.0.2.0/24<br/>ALB aqui"]
            PrivB["🔵 Subnet Privada AZ-b<br/>10.0.4.0/24<br/>ECS/Fargate"]
            RT_PubB["🔀 Route Table Pública"]
        end
        
        NAT["🔄 NAT Gateway<br/>Saída controlada<br/>para internet"]
        RT_Priv["🔀 Route Table Privada"]
        
        EIP["⚡ Elastic IP<br/>IP público fixo"]
    end
    
    IGW --> PubA
    IGW --> PubB
    PubA --> PrivA
    PubB --> PrivB
    NAT --> EIP
    EIP --> RT_Priv
    RT_Priv --> PrivA
    RT_Priv --> PrivB
    RT_PubA --> IGW
    RT_PubB --> IGW
    
    style IGW fill:#FFB6C1
    style PubA fill:#90EE90
    style PubB fill:#90EE90
    style PrivA fill:#87CEEB
    style PrivB fill:#87CEEB
    style NAT fill:#FFD700
    style EIP fill:#FFD700
```

**Componentes:**

| 🔧 Componente | 🎯 Função | 📊 Detalhes |
|---|---|---|
| **VPC** | Rede isolada na AWS | 10.0.0.0/16 (65k IPs) |
| **Internet Gateway** | Conecta VPC à internet | Permite requisições entrada |
| **Subnets Públicas** | Acessíveis da internet | ALB (Load Balancer) fica aqui |
| **Subnets Privadas** | NÃO acessíveis de fora | Containers ECS/Fargate isolados |
| **NAT Gateway** | Saída controlada | Permite downloads sem expor serviços |
| **Route Tables** | Definem caminhos | Pública→IGW, Privada→NAT |
| **Elastic IP** | IP público fixo | Associado ao NAT Gateway |

**✅ Benefícios:**
- 🔒 Isolamento: Containers não expostos à internet
- 📍 Multi-AZ: Alta disponibilidade em 2 data centers
- ⚡ Escalabilidade: Fácil adicionar mais subnets
- 🛡️ Segurança: Camadas de rede bem definidas

#### 🔒 Firewall (Security Groups) (`security.tf`)
```mermaid
graph TD
    A["🌍 INTERNET<br/>Qualquer IP do mundo"] -->|Porta 80 HTTP| B["⚖️ ALB Security Group"]
    
    B -->|Ingress: 0.0.0.0/0:80<br/>Egress: 0.0.0.0/0| C["ALB<br/>Application Load Balancer"]
    
    C -->|Tráfego permitido<br/>APENAS do ALB SG| D["🔒 ECS Security Group"]
    
    D -->|Ingress: porta 8000<br/>apenas do ALB| E["📦 Container 1<br/>10.0.3.x:8000"]
    D -->|Ingress: porta 8000<br/>apenas do ALB| F["📦 Container 2<br/>10.0.4.x:8000"]
    
    E -->|Egress: 0.0.0.0/0<br/>para downloads, APIs| G["☁️ Internet APIs<br/>ECR, CloudWatch, etc"]
    F -->|Egress: 0.0.0.0/0| G
    
    style A fill:#FFB6C1
    style B fill:#FFD700
    style C fill:#FFA500
    style D fill:#87CEEB
    style E fill:#90EE90
    style F fill:#90EE90
    style G fill:#DDA0DD
```

**Regras de Segurança:**

| 🚪 Direção | 🔓 ALB Security Group | 🔒 ECS Security Group |
|---|---|---|
| **Ingress (Entrada)** | `0.0.0.0/0:80` (mundo inteiro) | Porta 8000 (apenas ALB SG) |
| **Egress (Saída)** | `0.0.0.0/0` (qualquer destino) | `0.0.0.0/0` (APIs, downloads) |

**🛡️ Proteção Garantida:**
- ✅ Internet acessa **APENAS porta 80** do ALB
- ✅ Containers recebem tráfego **APENAS** do ALB
- ✅ Containers podem fazer requisições para fora (downloads, APIs externas)
- ✅ Isolamento em camadas (Defense in Depth)

#### 🎛️ Container Orchestration (`ecs.tf`)
```mermaid
graph TB
    A["📋 ECS Cluster<br/>fastapi-app-cluster"] --> B["🎯 ECS Service<br/>desired_count: 2"]
    
    B --> C["📦 Task Definition<br/>fastapi-app<br/>CPU: 0.25 vCPU<br/>Memory: 512 MB"]
    
    C --> D["Task Replica 1<br/>Subnet Privada AZ-a"]
    C --> E["Task Replica 2<br/>Subnet Privada AZ-b"]
    
    D -->|Container Port 8000| F["🔐 IAM Role<br/>Puxar ECR<br/>CloudWatch Logs"]
    E -->|Container Port 8000| F
    
    F --> G["📊 CloudWatch<br/>Log Group<br/>/ecs/fastapi-app<br/>Retention: 7 dias"]
    
    D --> H["⚖️ Application<br/>Load Balancer<br/>Target Group"]
    E --> H
    
    H --> I["🌐 ALB DNS<br/>http://alb-xxxxx<br/>amazonaws.com"]
    
    style A fill:#FFD700
    style B fill:#FFA500
    style C fill:#87CEEB
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#DDA0DD
    style G fill:#FF6347
    style H fill:#FFB6C1
    style I fill:#98FB98
```

**Componentes:**

| 🔧 Componente | 📝 Descrição | ⚙️ Configuração |
|---|---|---|
| **ECS Cluster** | Orquestrador de containers | `fastapi-app-cluster` |
| **ECS Service** | Mantém replicas rodando | `desired_count: 2` |
| **Task Definition** | Blueprint do container | CPU 0.25, RAM 512MB, Porta 8000 |
| **IAM Role** | Permissões | Puxar ECR, CloudWatch Logs |
| **CloudWatch Logs** | Monitora saída | Retém 7 dias `/ecs/fastapi-app` |
| **ALB Target Group** | Destino do load balancer | Conecta replicas ao ALB |

**🚀 Características:**
- ⚡ **Fargate** (Serverless): Sem gerenciar servidores
- 🔄 **Auto-recovery**: Se task falhar, ECS levanta outra
- 📊 **Multi-AZ**: Réplicas em zonas diferentes (HA)
- 🎚️ **Load Balancing**: Tráfego distribuído entre replicas
- 📈 **Escalável**: Ajustar `desired_count` para scale up/down

---

### 4️⃣ **Fluxo Completo de Requisição** 🔄
```mermaid
sequenceDiagram
    actor User as 👤 Usuário
    participant Browser as 🌐 Navegador
    participant IGW as 🌐 Internet<br/>Gateway
    participant ALB as ⚖️ Application<br/>Load Balancer
    participant Task1 as 📦 Container 1<br/>AZ-a
    participant Task2 as 📦 Container 2<br/>AZ-b
    participant CW as 📊 CloudWatch
    
    User->>Browser: 1. Acessar<br/>http://alb-dns.com/
    Browser->>IGW: 2. Requisição HTTP:80
    IGW->>ALB: 3. Roteia para ALB
    ALB->>Task1: 4a. Balancea para<br/>Container 1:8000
    ALB->>Task2: 4b. Balancea para<br/>Container 2:8000
    Task1->>Task1: 5a. FastAPI<br/>processa
    Task2->>Task2: 5b. FastAPI<br/>processa
    Task1->>CW: 6a. Envia logs
    Task2->>CW: 6b. Envia logs
    Task1->>ALB: 7a. Retorna JSON
    Task2->>ALB: 7b. Retorna JSON
    ALB->>Browser: 8. Resposta HTTP 200
    Browser->>User: 9. Exibe JSON
    
    Note over User,CW: {"status": "healthy", ...}
```

**Passo a Passo:**

| 📊 Etapa | 🎯 O que acontece | ⏱️ Tempo |
|---|---|---|
| 1️⃣ | Usuário acessa URL do ALB | ~0ms |
| 2️⃣ | Requisição chega via Internet Gateway | ~10ms |
| 3️⃣ | ALB recebe na porta 80 | ~20ms |
| 4️⃣ | ALB balanceia entre 2 containers | ~5ms |
| 5️⃣ | Container processa (main.py) | ~50ms |
| 6️⃣ | Logs enviados ao CloudWatch | ~30ms |
| 7️⃣ | Response JSON retorna | ~10ms |
| 8️⃣ | Browser recebe resposta | ~20ms |
| 9️⃣ | Usuário vê resultado | **~145ms total** |

---

### 5️⃣ **Resumo da Arquitetura Completa** 📋

| 🏗️ Camada | 💻 Tecnologia | 🎯 Função |
|---|---|---|
| **Aplicação** | 🐍 Python + FastAPI | API REST que responde requisições HTTP |
| **Container** | 🐳 Docker Multi-stage | Empacota app de forma isolada e leve |
| **Orquestração** | ⚙️ ECS Fargate | Gerencia 2 replicas serverless |
| **Balanceamento** | ⚖️ ALB (Application LB) | Distribui tráfego entre replicas |
| **Rede** | 🌐 VPC + Subnets Multi-AZ | Isolamento público/privado + HA |
| **Firewall** | 🔒 Security Groups | Controla fluxo de tráfego |
| **IaC** | 📋 Terraform | Automatiza toda infraestrutura |
| **Monitoramento** | 📊 CloudWatch | Logs centralizados e métricas |

---

## ✅ **Benefícios da Arquitetura Completa**

```
🚀 ESCALÁVEL          🔒 SEGURA             📊 RESILIENTE        💰 CUSTO-EFICIENTE
├─ +Replicas         ├─ Containers         ├─ Auto-recovery      ├─ Serverless
├─ Auto-scaling      │  isolados           ├─ Multi-AZ           ├─ Pay-per-use
└─ Load balancing    ├─ Subnets privadas   └─ Health checks      └─ Sem overhead
                     └─ IAM granular
                     
🔍 MONITORÁVEL       🤖 AUTOMATIZADO       ⚡ PERFORMÁTICO      📈 OBSERVÁVEL
├─ CloudWatch logs   ├─ Terraform IaC      ├─ Latência ~150ms    ├─ Métricas
├─ Métricas          ├─ Git-driven         ├─ Multi-AZ HA        ├─ Alertas
└─ Alertas           └─ Reproduzível       └─ Fargate optimizado └─ Dashboards
```

---

Pré-requisitos
- `terraform` (recomendado >= 1.0)
- `aws` CLI (credenciais configuradas: `aws configure`)
- `docker` (para construir a imagem localmente)
- Python 3.8+ (se for executar `main.py` localmente)

---

## 🚀 **Setup e Deploy Completo - Guia Prático**

```mermaid
graph LR
    A["📝 Step 1<br/>AWS Config"] --> B["🐳 Step 2<br/>Docker Build"]
    B --> C["📤 Step 3<br/>Push ECR"]
    C --> D["📝 Step 4<br/>Update Vars"]
    D --> E["🏗️ Step 5<br/>Terraform"]
    E --> F["🌐 Step 6<br/>Acessar App"]
    
    style A fill:#FFB6C1
    style B fill:#87CEEB
    style C fill:#FFD700
    style D fill:#DDA0DD
    style E fill:#90EE90
    style F fill:#98FB98
```

### 📝 **Passo 1: Configurar Credenciais AWS**
```bash
aws configure
# Preencha:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1 (ou sua região)
# - Default output format: json
```

### 🐳 **Passo 2: Construir Imagem Docker Localmente**

```bash
# Build com Multi-stage (builder + runner)
docker build -t devops-aws-app:latest .

# Testar localmente
docker run -p 8000:8000 devops-aws-app:latest

# ✅ Acessar: http://localhost:8000/
# Resposta esperada:
# {"status": "healthy", "message": "API rodando com sucesso!"}
```

### 📤 **Passo 3: Push da Imagem para Amazon ECR**

```bash
# 1️⃣ Criar repositório no ECR (primeira vez)
aws ecr create-repository --repository-name fastapi-app --region us-east-1

# 2️⃣ Fazer login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <SEU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 3️⃣ Tag a imagem com URI do ECR
docker tag devops-aws-app:latest <SEU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest

# 4️⃣ Push para ECR
docker push <SEU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest
```

> ⚠️ **Nota**: Substitua `<SEU_ACCOUNT_ID>` pelo seu AWS Account ID

### 📝 **Passo 4: Atualizar Variáveis Terraform**

Edite `Terraform/variables.tf`:

```hcl
variable "container_image" {
  # ANTES (placeholder):
  default = "nginx:latest"
  
  # DEPOIS (sua imagem ECR):
  default = "<SEU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest"
}
```

### 🏗️ **Passo 5: Deploy com Terraform**

```bash
cd Terraform

# ✅ Inicializa o Terraform (primeira vez)
terraform init

# ✅ Visualiza o plano de execução
terraform plan -out=tfplan

# ✅ Aplica o plano (cria infraestrutura na AWS)
terraform apply tfplan

# Alternativa: aplicar direto sem salvar plano
# terraform apply -auto-approve
```

**⏱️ Tempo esperado**: 3-5 minutos para toda infraestrutura ficar pronta

### 🌐 **Passo 6: Acessar a Aplicação**

```bash
# Obter DNS do ALB
cd Terraform
terraform output

# Copie a saída e acesse no navegador:
# http://<ALB_DNS>/
```

✅ Aguarde alguns segundos para as tarefas ECS ficarem saudáveis (Health Check)

---

## 📊 **Visualizando o Deploy**

```
0 min  ├─ terraform init
       └─ Download plugins AWS
       
1 min  ├─ terraform plan -out=tfplan
       └─ Valida configuração
       
2 min  ├─ terraform apply tfplan
       ├─ Cria VPC
       ├─ Cria Subnets
       ├─ Cria ALB
       ├─ Cria ECS Cluster
       └─ Inicia 2 tasks
       
4 min  ├─ Tasks ficam RUNNING
       ├─ Health Check passa
       └─ ✅ Pronto para acessar!
```

Pontos importantes sobre variáveis e outputs
- Para alterar valores padrão, edite `Terraform/variables.tf` ou use `-var` / `-var-file` no `terraform apply`.
- Para visualizar outputs após o deploy:

```bash
cd Terraform
terraform output
```

---

## 🔧 **Troubleshooting - Soluções Rápidas**

### ❌ **"Acesso negado ao ECR" ou "Credenciais inválidas"**

```bash
# ✅ Verifique se o aws configure foi feito corretamente
aws s3 ls  # Teste básico de credenciais

# ✅ Se usar perfil específico:
export AWS_PROFILE=seu-perfil
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ...
```

**Causas comuns:**
- ❌ Credenciais expiradas
- ❌ IAM sem permissões ECR
- ❌ Região incorreta

### ❌ **"Terraform não encontra variáveis de região"**

```bash
# ✅ Certifique-se de estar na pasta Terraform/
cd Terraform/

# ✅ Verifique se providers.tf existe
ls -la providers.tf

# ✅ Reinicie terraform init
rm -rf .terraform
terraform init
```

### ❌ **"ALB Health Check Falha"**

```bash
# ✅ Aguarde 2-3 minutos para tarefas ficarem saudáveis
# ✅ Verifique logs no CloudWatch:
aws logs tail /ecs/fastapi-app --follow

# ✅ Verifique status das tasks:
aws ecs list-tasks --cluster fastapi-app-cluster
aws ecs describe-tasks --cluster fastapi-app-cluster --tasks <TASK_ARN>
```

**Causas comuns:**
- ⏳ Container ainda iniciando
- 🔒 Security Group bloqueando
- 🖥️ Aplicação com erro

### ❌ **"Porta 8000 já em uso" (teste local)**

```bash
# ✅ Use porta diferente:
docker run -p 9000:8000 devops-aws-app:latest

# ✅ Ou mate o processo que ocupa 8000:
# Windows:
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# macOS/Linux:
lsof -i :8000
kill -9 <PID>
```

---

## 🗑️ **Destruir Infraestrutura (Evitar Custos)**

```bash
cd Terraform

# 📋 Visualiza o que será destruído
terraform plan -destroy

# ⚠️ Destroi tudo (IRREVERSÍVEL!)
terraform destroy -auto-approve

# 📁 Remover arquivo de estado local (opcional)
rm -r .terraform terraform.tfstate*
```

> ⚠️ **ATENÇÃO**: Isto é **IRREVERSÍVEL**. Tenha certeza antes de executar!

Segurança e boas práticas
- ✅ **Nunca comite** credenciais ou arquivos com secrets no repositório
- ✅ **Use perfis IAM** com privilégios mínimos (least privilege)
- ✅ **Armazene secrets** em cofres seguros:
  - 🔐 AWS Secrets Manager
  - 🔐 AWS Systems Manager Parameter Store
  - 🔐 HashiCorp Vault
  - 🔐 `terraform.tfvars` (adicione ao `.gitignore`)
- ✅ **Monitore logs** regularmente no CloudWatch
- ✅ **Use Multi-AZ** para alta disponibilidade (já configurado)
- ✅ **Subnets privadas** para containers (já configurado)
- ✅ **Security Groups restritivos** (ALB público, ECS privado - já configurado)

---

## 📊 **Dashboard de Monitoramento**

Após deploy, acesse no AWS Console:

| 📈 Métrica | 🔗 Local | 👁️ O que acompanhar |
|---|---|---|
| **CloudWatch Logs** | `/ecs/fastapi-app` | Saída dos containers |
| **ECS Cluster** | ECS → Clusters → fastapi-app-cluster | Status das tasks |
| **ALB Health** | EC2 → Target Groups | Health check status |
| **Métricas ALB** | CloudWatch → Metrics → ApplicationELB | Requisições/latência |
| **VPC Flow Logs** | VPC → Flow Logs | Tráfego de rede |

---

## 📁 **Estrutura do Projeto**

```
DevOps-AWS/
├── 📄 main.py                      ← Aplicação FastAPI
├── 🐳 Dockerfile                   ← Build Multi-stage (Builder + Runner)
├── 📖 README.md                    ← Este arquivo
└── 🏗️ Terraform/
    ├── 🌐 network.tf               ← VPC, Subnets, NAT Gateway, Route Tables
    ├── 🔒 security.tf              ← Security Groups (ALB + ECS)
    ├── ⚙️ ecs.tf                    ← ECS Cluster, Task Definition, Service
    ├── ⚖️ alb.tf                    ← Application Load Balancer
    ├── 📋 providers.tf             ← Configuração AWS (versão, região)
    ├── 📝 variables.tf             ← Variáveis customizáveis
    ├── 📤 outputs.tf               ← Saídas (DNS ALB, IPs, etc)
    ├── 💾 terraform.tfstate        ← Estado da infraestrutura (auto-gerado)
    └── .terraform/                 ← Plugins Terraform (auto-gerado)
```

---

## 🚀 **Próximos Passos Sugeridos - Roadmap**

```mermaid
graph TD
    A["✅ Setup Local"] --> B["✅ Build Docker"]
    B --> C["✅ Deploy AWS"]
    C --> D["📊 Monitorar"]
    D --> E["🔄 Auto-scaling"]
    E --> F["🚀 CI/CD"]
    F --> G["🔐 Backup & DR"]
    G --> H["💰 Otimizar Custos"]
    
    style A fill:#90EE90
    style B fill:#90EE90
    style C fill:#90EE90
    style D fill:#FFD700
    style E fill:#FFD700
    style F fill:#87CEEB
    style G fill:#DDA0DD
    style H fill:#FF6347
```

**Fase 1 - Essencial (Hoje):**
- ✅ Testar localmente: `docker build` e `docker run`
- ✅ Validar credenciais AWS: `aws s3 ls`
- ✅ Push para ECR: Imagem no repositório
- ✅ Deploy Terraform: `terraform apply`
- ✅ Validar endpoint: Acessar ALB DNS

**Fase 2 - Observabilidade (Esta Semana):**
- 📊 Verificar logs: `aws logs tail /ecs/fastapi-app`
- 📈 Monitorar: CloudWatch Metrics & Alarms
- 🔍 Dashboard: Métricas customizadas

**Fase 3 - Escalabilidade (Próximas Semanas):**
- 🔄 Scale replicas: `desired_count` em `ecs.tf`
- 📈 Auto-scaling: Baseado em CPU/Memória
- 🎚️ Load balancing: Validar distribuição

**Fase 4 - Automação (Futuro):**
- 🚀 CI/CD: GitHub Actions ou AWS CodePipeline
- 🔄 Rollback: Automático em falhas
- 📋 Approval: Gatekeeping em prod

**Fase 5 - Resiliência:**
- 🔐 Backup: Multi-region
- 📋 Disaster Recovery: Plano de contingência
- 💰 Otimização: Reduzir custos 20-40%

---

## 📚 **Documentação e Recursos**

```
DOCUMENTAÇÃO OFICIAL
├─ Terraform AWS Provider
│  └─ https://registry.terraform.io/providers/hashicorp/aws/latest/docs
├─ FastAPI Documentation
│  └─ https://fastapi.tiangolo.com
├─ Docker Multi-stage Builds
│  └─ https://docs.docker.com/build/building/multi-stage/
└─ AWS ECS Developer Guide
   └─ https://docs.aws.amazon.com/AmazonECS/latest/developerguide/

FERRAMENTAS ÚTEIS
├─ aws-cli: Interagir com AWS
├─ terraform-docs: Gerar documentação
├─ terragrunt: Wrapper Terraform
├─ localstack: Testar AWS localmente
└─ aws-vault: Gerenciar credenciais

COMUNIDADE
├─ GitHub Issues: Bugs/Features
├─ Stack Overflow: Perguntas técnicas
├─ AWS Support: Problemas infraestrutura
└─ Reddit /r/devops: Comunidade
```

---

## 🤝 **Contribuindo**

Contribuições são bem-vindas! Processo:

1. **Fork** o repositório
2. **Crie uma branch** (`git checkout -b feature/NovaFeature`)
3. **Commit** suas mudanças (`git commit -m 'Adiciona NovaFeature'`)
4. **Push** para a branch (`git push origin feature/NovaFeature`)
5. **Abra um Pull Request**

---

## 📝 **Licença**

Este projeto está licenciado sob a Licença MIT - veja o arquivo LICENSE para detalhes.

---

## 📞 **Contato & Suporte**

Tem dúvidas? Abra uma **Issue** no repositório!

- 📧 Email: seu-email@exemplo.com
- 🐦 Twitter: @seu-twitter
- 💬 Discord: seu-servidor-discord

---

## 🎯 **Objetivo Educacional**

Este projeto demonstra **boas práticas de:**
- ✅ Infrastructure as Code (Terraform)
- ✅ Containerização (Docker Multi-stage)
- ✅ DevOps & Cloud Engineering
- ✅ Arquitetura em camadas
- ✅ Alta disponibilidade & Escalabilidade
- ✅ Segurança em nuvem

**Perfeito para:**
- 👨‍💼 Profissionais DevOps
- 👨‍💻 Engenheiros de Software
- 📚 Estudantes de Cloud & AWS
- 🎓 Pessoas aprendendo Terraform

---

## ⭐ Aprendizados Principais

| 📚 Conceito | 💡 O que você aprenderá | 🎯 Aplicação |
|---|---|---|
| **IaC** | Automatizar infraestrutura com código | Reproduzibilidade & Versionamento |
| **Docker** | Containerizar aplicações | Consistência entre ambientes |
| **AWS** | Serviços em nuvem | Escalabilidade & Confiabilidade |
| **Terraform** | Gerenciar recursos AWS | GitOps & CI/CD |
| **Segurança** | Isolamento de rede | Defense in Depth |
| **DevOps** | Automação de deploys | Velocidade & Qualidade |

---

**Última atualização**: Julho 2025  
**Status**: Test  
**Versão**: 1.0.0  
**Mantido por**: Samuel Santos