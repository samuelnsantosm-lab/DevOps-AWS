# network.tf

# ==========================================
# 1. VPC (Virtual Private Cloud)
# ==========================================
# Cria uma rede virtual isolada para a sua aplicação na AWS
resource "aws_vpc" "main" {
  # Bloco CIDR que define o escopo de IPs da VPC (65.536 IPs disponíveis)
  cidr_block           = "10.0.0.0/16"
  # Ativa o suporte de resolução DNS nativo da AWS dentro da rede
  enable_dns_support   = true
  # Garante que as instâncias com IP público recebam um nome de host DNS correspondente
  enable_dns_hostnames = true
  # Tag para identificar facilmente o recurso no console da AWS usando o nome da aplicação
  tags = { Name = "${var.app_name}-vpc" }
}

# ==========================================
# 2. Internet Gateway
# ==========================================
# Permite a comunicação entre os recursos da VPC e a internet pública
resource "aws_internet_gateway" "igw" {
  # Vincula o gateway diretamente à VPC criada anteriormente
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.app_name}-igw" }
}

# ==========================================
# 3. Subnets Públicas (Multi-AZ)
# ==========================================
# Subnet pública localizada na primeira Zona de Disponibilidade (Ex: us-east-1a)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  # Faixa de IPs específica para esta subnet (256 IPs disponíveis)
  cidr_block              = "10.0.1.0/24"
  # Concatena a região das variáveis com a letra 'a' para definir a AZ
  availability_zone       = "${var.aws_region}a"
  # Garante que qualquer recurso criado aqui ganhe um IP público automaticamente
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.app_name}-public-a" }
}

# Subnet pública secundária na segunda Zona de Disponibilidade (Ex: us-east-1b)
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  # Define a segunda AZ adicionando a letra 'b'
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.app_name}-public-b" }
}

# ==========================================
# 4. Subnets Privadas (Multi-AZ)
# ==========================================
# Subnet privada na AZ 'a' para recursos que não devem ser acessados diretamente da internet (Ex: Banco de Dados/Containers)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  # Por padrão, recursos aqui NÃO recebem IP público (map_public_ip_on_launch é omitido)
  tags              = { Name = "${var.app_name}-private-a" }
}

# Subnet privada secundária na AZ 'b' para garantir alta disponibilidade
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.app_name}-private-b" }
}

# ==========================================
# 5. NAT Gateway (Requer Elastic IP)
# ==========================================
# Aloca um IP público estático e fixo (Elastic IP) dedicado para o NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

# Cria o NAT Gateway para permitir que recursos nas subnets privadas acessem a internet (Ex: baixar atualizações)
resource "aws_nat_gateway" "nat" {
  # Associa o Elastic IP criado acima ao gateway
  allocation_id = aws_eip.nat.id
  # O NAT Gateway precisa morar obrigatoriamente dentro de uma subnet pública para funcionar
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.app_name}-nat" }
  # Força o Terraform a criar o Internet Gateway antes, evitando falhas de conectividade na criação
  depends_on = [aws_internet_gateway.igw]
}

# ==========================================
# 6. Tabelas de Roteamento (Route Tables)
# ==========================================
# Tabela de rotas para as subnets públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  # Rota padrão: todo tráfego de saída destinado à internet (0.0.0.0/0) vai para o Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Tabela de rotas para as subnets privadas
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  # Rota padrão: todo tráfego de saída das subnets privadas vai para a internet através do NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# ==========================================
# 7. Associações de Tabela de Roteamento
# ==========================================
# Vincula a subnet pública A às regras da tabela de rotas pública
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Vincula a subnet pública B às regras da tabela de rotas pública
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Vincula a subnet privada A às regras da tabela de rotas privada (passando pelo NAT)
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# Vincula a subnet privada B às regras da tabela de rotas privada (passando pelo NAT)
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
