# Definimos el provider
provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  ami    = var.UBUNTU_AMI[local.region]
}

data "aws_vpc" "vpc_ae" {
  tags = {
    Name = "AE-Media-VPC"
  }
}

data "aws_subnet" "subnets" {
  vpc_id = data.aws_vpc.vpc_ae.id
  for_each = var.servers
  availability_zone = "${local.region}${each.value.az}"
}

resource "aws_instance" "server" {
  for_each = var.servers
  ami = local.ami
  instance_type = var.EC2_TYPE
  vpc_security_group_ids = [ aws_security_group.terraform_sg.id ]
  subnet_id = data.aws_subnet.subnets[each.key].id
  # Script de inicio
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y busybox-static
              echo "Hola che culiao! Soy el ${each.value.nombre}!!!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF              
  # De esta forma asignamos tags a la instancia, por ej. el nombre, pero no es requerido
  tags = {
    Name = each.value.nombre
  }
}

# Definimos el security group para las instancias EC2
resource "aws_security_group" "terraform_sg" {
  name = "servers-sg"
  # Tambien definimos que se asigne este security group a la misma VPC
  vpc_id = data.aws_vpc.vpc_ae.id
  ingress {
    # Permitimos ahora el acceso solamente al LB
    # cidr_blocks = [ "0.0.0.0/0" ]
    security_groups = [aws_security_group.alb.id]
    description = "Acceso al puerto ${var.server_port}"
    from_port = var.server_port
    to_port = var.server_port
    protocol = "TCP"
  }
}

# Definimos el load balancer
resource "aws_lb" "alb" {
  load_balancer_type = "application"
  name = "servers-alb"
  # Security group del LB, no es el mismo de las EC2
  security_groups = [ aws_security_group.alb.id ]
  # Indicamos las subredes que alcanza el LB, reutilizando los datasource anteriores
  # subnets = [ data.aws_subnet.az1.id, data.aws_subnet.az2.id ]
  # Ahora refactorizado
  subnets = [for subnet in data.aws_subnet.subnets: subnet.id]
}

# Security Group para el LB
resource "aws_security_group" "alb" {
  name = "alb-sg"
  # Tambien definimos que se asigne este security group a la misma VPC
  vpc_id = data.aws_vpc.vpc_ae.id
  # Para el LB damos acceso al puerto 80 y después direccionamos al 8080 de las EC2
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto ${var.lb_port} en el LB"
    from_port = var.lb_port
    to_port = var.lb_port
    protocol = "TCP"
  }
  
  egress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto ${var.server_port} en las EC2"
    from_port = var.server_port
    to_port = var.server_port
    protocol = "TCP"
  }
}

# Definimos un Target Group para las instancias EC2
resource "aws_lb_target_group" "alb-tg" {
  name = "alb-ec2-targetgroup"
  port = var.lb_port
  vpc_id = data.aws_vpc.vpc_ae.id
  protocol = "HTTP"

  # Defino una prueba de comprobación para que el LB decida a qué instancia mandar tráfico
  health_check {
    enabled = true
    matcher = "200" # código 200 al request HTTP
    path = "/"      
    port = var.server_port  # Puerto en la EC2
    protocol = "HTTP"
  }
}

# Defino los attachments para asignar el targetgroup a las instancias
resource "aws_lb_target_group_attachment" "servers" {
  for_each = var.servers
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id = aws_instance.server[each.key].id
  port = var.server_port
}

# resource "aws_lb_target_group_attachment" "server2" {
#   target_group_arn = aws_lb_target_group.alb-tg.arn
#   target_id = aws_instance.server2.id
#   port = var.server_port
# }

# Defino un listener para hacer forward del puerto 80 al 8080
resource "aws_lb_listener" "alb-tg-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = var.lb_port

  default_action {
   target_group_arn = aws_lb_target_group.alb-tg.arn
   type = "forward"  
  }
}