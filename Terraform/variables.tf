# variables.tf

# Define a região geográfica padrão da AWS onde os recursos serão criados
variable "aws_region" {
  # Valor padrão caso nenhuma outra região seja informada explicitamente
  default = "us-east-1"
}

# Define o nome base da aplicação para organizar e identificar os recursos
variable "app_name" {
  # Nome padrão usado na nomeação de clusters, serviços e tarefas
  default = "fastapi-app"
}

# Define a porta interna em que a aplicação dentro do container vai rodar
variable "container_port" {
  # Porta padrão (neste caso, configurada para o framework FastAPI)
  default = 8000
}

# Substitua pela URI da imagem no seu Amazon ECR após o push da Fase 1
# Define o endereço da imagem Docker que será baixada pelo serviço de container
variable "container_image" {
  # PLACEHOLDER: Imagem padrão do Nginx usada apenas como teste inicial
  default = "nginx:latest" 
}
