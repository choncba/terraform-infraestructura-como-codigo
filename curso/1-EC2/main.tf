# Definimos el provider
provider "aws" {
  region = "us-east-1"
}

# Definimos el recurso a implementar
resource "aws_instance" "server1" {
  # Imagen del SO a utilizar, lo sacamos de la lista de imágenes de instancias EC2 de la consola de aws
  ami = "ami-053b0d53c279acc90" 
  # Capacidad de la VM
  instance_type = "t2.micro"
  # Security group asociado
  vpc_security_group_ids = [ aws_security_group.terraform_sg.id ]
  # Script de inicio
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y busybox-static
              echo "Hola che culiao!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF              
  # De esta forma asignamos tags a la instancia, por ej. el nombre, pero no es requerido
  tags = {
    Name = "server1"
  }
}

resource "aws_security_group" "terraform_sg" {
  name = "server1-sg"
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto 8080"
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
  }
}