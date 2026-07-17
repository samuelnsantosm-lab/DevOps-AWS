# providers.tf

# O bloco 'terraform' define as configurações globais do próprio Terraform
terraform {
  # Especifica os provedores externos necessários para este projeto
  required_providers {
    # Define um apelido local 'aws' para o provedor da AWS
    aws = {
      # Indica a origem oficial do provedor no registro da HashiCorp
      source  = "hashicorp/aws"
      # Restringe a versão: aceita atualizações seguras dentro da versão 5.x (>= 5.0, < 6.0)
      version = "~> 5.0"
    }
  }
}

# O bloco 'provider' define as configurações específicas para o provedor conectado
provider "aws" {
  # Define a região geográfica da AWS onde os recursos serão criados
  # O valor é puxado dinamicamente de uma variável chamada 'aws_region'
  region = var.aws_region
}
