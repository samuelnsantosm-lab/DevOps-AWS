# security.tf

# ==============================================================================
# Security Group do Load Balancer (ALB) - Aberto para Internet na porta 80
# ==============================================================================
# Atua como a primeira linha de defesa, controlando o tráfego que chega da internet
resource "aws_security_group" "alb_sg" {
  name        = "${var.app_name}-alb-sg"
  description = "Permite trafego HTTP de entrada para o ALB"
  vpc_id      = aws_vpc.main.id

  # Regra de Entrada (Ingress): Controla o tráfego que entra no Load Balancer
  ingress {
    from_port   = 80          # Porta inicial permitida (HTTP padrão)
    to_port     = 80          # Porta final permitida
    protocol    = "tcp"       # Protocolo de rede utilizado pelo protocolo HTTP
    cidr_blocks = ["0.0.0.0/0"] # Permite o acesso vindo de QUALQUER endereço IP do mundo
  }

  # Regra de Saída (Egress): Controla para onde o Load Balancer pode enviar dados
  egress {
    from_port   = 0           # Porta 0 combinada com protocolo "-1" significa "todas as portas"
    to_port     = 0
    protocol    = "-1"        # Protocolo "-1" significa todos os protocolos (TCP, UDP, ICMP, etc.)
    cidr_blocks = ["0.0.0.0/0"] # Permite enviar respostas e tráfego de saída para qualquer destino
  }
}

# ==============================================================================
# Security Group do ECS/Fargate - Recebe tráfego SOMENTE do ALB
# ==============================================================================
# Garante o isolamento dos containers, impedindo acessos diretos vindos de fora da rede
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-ecs-sg"
  description = "Permite trafego do ALB para a aplicacao"
  vpc_id      = aws_vpc.main.id

  # Regra de Entrada (Ingress): Restringe severamente quem pode falar com os containers
  ingress {
    from_port       = var.container_port # Abre a porta dinâmica definida na variável (ex: 8000)
    to_port         = var.container_port
    protocol        = "tcp"
    # REGRA CRÍTICA DE SEGURANÇA: Não aceita IPs diretos. 
    # Só permite tráfego vindo de recursos associados ao Security Group do ALB criado acima.
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Regra de Saída (Egress): Controla o tráfego iniciado de dentro dos containers para fora
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Obrigatório para que o Fargate consiga se comunicar com a internet,
                                # permitindo autenticar na AWS, baixar a imagem Docker do ECR e consultar APIs.
  }
}
