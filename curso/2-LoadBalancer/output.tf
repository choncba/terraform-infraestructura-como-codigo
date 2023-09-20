output "dns_publica_az_1a" {
    # ver https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#attribute-reference
    description = "DNS pública del servidor 1:"
    # value = aws_instance.server1.public_dns
    # Para hacerlo más completo
    value = "http://${aws_instance.server1.public_dns}:8080"  
}

output "ipv4_az_1a" {
    description = "IP v4 del servidor 1:"
    value = aws_instance.server1.public_ip
}

output "dns_publica_az_1b" {
    # ver https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#attribute-reference
    description = "DNS pública del servidor 2:"
    # value = aws_instance.server1.public_dns
    # Para hacerlo más completo
    value = "http://${aws_instance.server2.public_dns}:8080"  
}

output "ipv4_az_1b" {
    description = "IP v4 del servidor 2:"
    value = aws_instance.server2.public_ip
}

output "dns_publica_load_balancer" {
  description = "DNS pública del load balancer"
  value = "http://${aws_lb.alb.dns_name}"
}