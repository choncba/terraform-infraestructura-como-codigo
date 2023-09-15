output "dns_publica" {
    # ver https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#attribute-reference
    description = "DNS pública del servidor:"
    # value = aws_instance.server1.public_dns
    # Para hacerlo más completo
    value = "http://${aws_instance.server1.public_dns}:8080"  
}

output "ipv4" {
    description = "IP v4 del servidor:"
    value = aws_instance.server1.public_ip
}