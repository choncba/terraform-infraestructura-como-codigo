# Definimos el provider
provider "aws" {
  region = "us-east-1"
}

# Definimos el recurso a implementar
resource "aws_instance" "server1" {
  ami = "ami-053b0d53c279acc90" # Imagen del SO a utilizar, lo sacamos de la lista de instancias de la consola de aws
  instance_type = "t2.micro"    # Capacidad de la VM
}