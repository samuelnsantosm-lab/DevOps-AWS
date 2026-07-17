# alb.tf

# ==============================================================================
# 1. Application Load Balancer (ALB)
# ==============================================================================
# Cria o balanceador de carga que recebe todas as requisições web externas
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  # Define que o balanceador é público (voltado para a internet) e não interno
  internal           = false
  # Tipo 'application' opera na Camada 7 (HTTP/HTTPS), ideal para APIs e apps web
  load_balancer_type = "application"
  # Vincula o Security Group do ALB (criado no security.tf) que abre a porta 80
  security_groups    = [aws_security_group.alb_sg.id]
  # Distribui o ALB entre as duas subnets públicas para garantir Alta Disponibilidade (Multi-AZ)
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# ==============================================================================
# 2. Target Group (Grupo de Destino)
# ==============================================================================
# Define para onde o ALB deve encaminhar o tráfego limpo e como checar a saúde dos containers
resource "aws_lb_target_group" "main" {
  name        = "${var.app_name}-tg"
  # Encaminha as requisições para a porta interna que a aplicação está escutando (ex: 8000)
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  # REGRA CRÍTICA: Tipo 'ip' é obrigatório para o ECS Fargate, pois cada container 
  # ganha uma placa de rede própria com IP privado dentro da VPC (modo de rede awsvpc)
  target_type = "ip"

  # Configuração do Health Check (Monitoramento de Saúde dos Containers)
  health_check {
    # Rota que o ALB vai testar periodicamente (neste caso, a raiz '/' do FastAPI)
    path                = "/" 
    protocol            = "HTTP"
    # O container é considerado saudável apenas se responder com o código HTTP 200
    matcher             = "200"
    # Tempo em segundos entre cada tentativa de verificação
    interval            = 30
    # Tempo limite em segundos para o container responder antes de falhar a checagem
    timeout             = 5
    # Número de sucessos consecutivos necessários para marcar um container com problema como saudável de novo
    healthy_threshold   = 2
    # Número de falhas consecutivas necessárias para retirar um container instável do balanceamento
    unhealthy_threshold = 2
  }
}

# ==============================================================================
# 3. ALB Listener (Ouvinte HTTP)
# ==============================================================================
# Configura o ALB para escutar o tráfego que chega na porta pública padrão da web
resource "aws_lb_listener" "http" {
  # Vincula este ouvinte ao Load Balancer criado no passo 1
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Ação padrão realizada pelo ouvinte quando uma requisição chega
  default_action {
    # 'forward' significa repassar o fluxo de dados diretamente para o Target Group configurado
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
