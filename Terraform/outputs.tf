# outputs.tf

# ==============================================================================
# Saídas (Outputs) do Terraform
# ==============================================================================
# Define uma variável de saída para exibir informações importantes no terminal após a execução
output "alb_dns_name" {
  # Descrição textual explicando o que este dado representa
  description = "A URL de acesso a API via Load Balancer"
  
  # Resgata dinamicamente o endereço DNS público gerado automaticamente pela AWS para o seu ALB.
  # É esse endereço que você vai colar no navegador ou no Postman para testar o seu FastAPI.
  value       = aws_lb.main.dns_name
}
