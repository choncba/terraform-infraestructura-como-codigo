# Definimos el provider
provider "aws" {
  region = "us-east-1"
}

# Datasource que nos devuelve el id de la vpc default
data "aws_vpc" "default" {
  default = true
}

# Como tengo multiples VPC, para usar el id de la vpc "AE-Media-VPC" la extraigo como datasource
data "aws_vpc" "vpc_ae" {
  tags = {
    Name = "AE-Media-VPC"
  }
}
# Definimos 2 datasources para extraer la información de las subredes correspondientes a us-east-1a y us-east-1b 
# de la VPC con el id de "AE-Media-VPC"
data "aws_subnet" "az1" {
  vpc_id = data.aws_vpc.vpc_ae.id
  availability_zone = "us-east-1a"
}

data "aws_subnet" "az2" {
  vpc_id = data.aws_vpc.vpc_ae.id
  availability_zone = "us-east-1b"
}

# Definimos 2 instancias EC2
resource "aws_instance" "server1" {
  # Imagen del SO a utilizar, lo sacamos de la lista de imágenes de instancias EC2 de la consola de aws
  ami = "ami-053b0d53c279acc90" 
  # Capacidad de la VM
  instance_type = "t2.micro"
  # Security group asociado
  vpc_security_group_ids = [ aws_security_group.terraform_sg.id ]
  # Asignamos la subred correspondiente a us-east-1a
  # subnet_id = "subnet-01e50bfb5f6a3c07a"
  # Lo mismo, pero referenciado al datasource correspondiente a us-east-1a
  subnet_id = data.aws_subnet.az1.id
  # Script de inicio
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y busybox-static
              echo "Hola che culiao! Soy el Server 1!!!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF              
  # De esta forma asignamos tags a la instancia, por ej. el nombre, pero no es requerido
  tags = {
    Name = "server1"
  }
}

resource "aws_instance" "server2" {
  # Imagen del SO a utilizar, lo sacamos de la lista de imágenes de instancias EC2 de la consola de aws
  ami = "ami-053b0d53c279acc90" 
  # Capacidad de la VM
  instance_type = "t2.micro"
  # Security group asociado
  vpc_security_group_ids = [ aws_security_group.terraform_sg.id ]
  # Asignamos la subred correspondiente a us-east-1b
  # subnet_id = "subnet-06c13c88594553ee3"  
  # Lo mismo, pero referenciado al datasource correspondiente a us-east-1a
  subnet_id = data.aws_subnet.az2.id
  # Script de inicio
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y busybox-static
              echo "Hola che culiao! Desde el Server 2!!!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF              
  # De esta forma asignamos tags a la instancia, por ej. el nombre, pero no es requerido
  tags = {
    Name = "server2"
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
    description = "Acceso al puerto 8080"
    from_port = 8080
    to_port = 8080
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
  subnets = [ data.aws_subnet.az1.id, data.aws_subnet.az2.id ]
}

# Security Group para el LB
resource "aws_security_group" "alb" {
  name = "alb-sg"
  # Tambien definimos que se asigne este security group a la misma VPC
  vpc_id = data.aws_vpc.vpc_ae.id
  # Para el LB damos acceso al puerto 80 y después direccionamos al 8080 de las EC2
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto 80 en el LB"
    from_port = 80
    to_port = 80
    protocol = "TCP"
  }
  
  egress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto 8080 en las EC2"
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
  }
}

# Definimos un Target Group para las instancias EC2
resource "aws_lb_target_group" "alb-tg" {
  name = "alb-ec2-targetgroup"
  port = 80
  vpc_id = data.aws_vpc.vpc_ae.id
  protocol = "HTTP"

  # Defino una prueba de comprobación para que el LB decida a qué instancia mandar tráfico
  health_check {
    enabled = true
    matcher = "200" # código 200 al request HTTP
    path = "/"      
    port = "8080"   # Puerto en la EC2
    protocol = "HTTP"
  }
}

# Defino los attachments para asignar el targetgroup a las instancias
resource "aws_lb_target_group_attachment" "server1" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id = aws_instance.server1.id
  port = 8080
}

resource "aws_lb_target_group_attachment" "server2" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id = aws_instance.server2.id
  port = 8080
}

# Defino un listener para hacer forward del puerto 80 al 8080
resource "aws_lb_listener" "alb-tg-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80

  default_action {
   target_group_arn = aws_lb_target_group.alb-tg.arn
   type = "forward"  
  }
}