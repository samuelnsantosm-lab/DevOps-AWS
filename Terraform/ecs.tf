# ecs.tf

# ==============================================================================
# 1. ECS Cluster
# ==============================================================================
# Cria o cluster lógico do Amazon ECS onde as tarefas e serviços vão rodar
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
}

# ==============================================================================
# 2. IAM Role de Execução (ECS Execution Role)
# ==============================================================================
# Cria a role necessária para o agente do ECS realizar ações de infraestrutura em seu nome
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-ecs-exec-role"
  
  # Política que confia e permite que o serviço de tarefas do ECS assuma essa role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Anexa a política padrão da AWS que dá permissões para puxar imagens do ECR e gravar no CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==============================================================================
# 3. CloudWatch Log Group
# ==============================================================================
# Cria o grupo de logs no CloudWatch para coletar a saída padrão (stdout/stderr) da aplicação
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.app_name}"
  # Retém os logs por apenas 7 dias para otimizar e economizar custos de armazenamento
  retention_in_days = 7
}

# ==============================================================================
# 4. ECS Task Definition (Definição do Container)
# ==============================================================================
# Define as especificações técnicas, recursos e o blueprint de como o container deve rodar
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  # Modo awsvpc dá a cada tarefa seu próprio endereço IP privado interno da VPC
  network_mode             = "awsvpc"
  # Define que a infraestrutura será totalmente gerenciada (Serverless) via Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Equivale a 0.25 vCPU
  memory                   = "512" # Equivale a 512 MB de Memória RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Bloco JSON com as configurações específicas do container Docker
  container_definitions = jsonencode([{
    name      = var.app_name
    image     = var.container_image
    # Se este container falhar ou parar, toda a tarefa será encerrada e substituída
    essential = true
    
    # Mapeamento de portas (no modo awsvpc, a porta do container e do host devem ser iguais)
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    
    # Configuração para redirecionar os logs gerados pelo container para o CloudWatch
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ==============================================================================
# 5. Serviço ECS (ECS Service)
# ==============================================================================
# Mantém o número desejado de instâncias da Task Definition rodando e integradas ao ALB
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  # Mantém sempre 2 réplicas rodando simultaneamente para garantir Alta Disponibilidade
  desired_count   = 2 
  launch_type     = "FARGATE"

  # Configurações de rede onde as tarefas do serviço serão instanciadas
  network_configuration {
    # Isola os containers inserindo-os exclusivamente dentro das subnets privadas
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    # Associa o firewall restrito (criado no security.tf) que só aceita chamadas do ALB
    security_groups  = [aws_security_group.ecs_sg.id]
    # Mantém falso para que os containers não fiquem expostos diretamente à internet pública
    assign_public_ip = false 
  }

  # Conecta as tarefas do ECS ao Application Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  # Força o ECS a esperar o Listener HTTP do ALB estar pronto antes de subir o serviço, evitando erros de vínculo
  depends_on = [aws_lb_listener.http]
}
