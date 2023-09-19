# Definimos el provider
provider "aws" {
  region = "us-east-1"
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

resource "aws_security_group" "terraform_sg" {
  name = "servers-sg"
  # Tambien definimos que se asigne este security group a la misma VPC
  vpc_id = data.aws_vpc.vpc_ae.id
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto 8080"
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
  }
}