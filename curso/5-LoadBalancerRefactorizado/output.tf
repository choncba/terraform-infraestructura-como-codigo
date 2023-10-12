# Outputs refactorizados

output "dns_publicas" {
    description = "DNS públicas de los servidores:"
    value = [for server in aws_instance.server: 
        "http://${server.public_dns}:${var.server_port}"
        ]
}

output "direcciones_ipv4" {
    description = "Direcciones IP v4 de los servidores:"
    value = [for server in aws_instance.server:
    server.public_ip
    ]
}

output "dns_publica_load_balancer" {
  description = "DNS pública del load balancer"
  value = "http://${aws_lb.alb.dns_name}:${var.lb_port}"
}