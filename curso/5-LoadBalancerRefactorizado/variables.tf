variable "server_port" {
  description = "Puerto de los servidores"
  type = number
  default = 8080

  validation {
    condition = var.server_port >= 5000 && var.server_port <= 10000
    error_message = "Utilizar puertos entre 5000 y 10000"
  }
}

variable "lb_port" {
  description = "Puerto del Load Balancer"
  type = number
  default = 80
}

variable "EC2_TYPE" {
  description = "Tipo de instancia EC2 utilizada"
  type = string
  default = "t2.micro"
}

variable "UBUNTU_AMI" {
  description = "ID de imagen de Ubuntu segun región de AWS"
  type = map(string)
  default = {
    "us-east-1" = "ami-053b0d53c279acc90"
    "eu-west-1" = "ami-095df877cd67dfd34"
  }
  
}

# Defino el nombre y la AZ de cada server
variable "servers" {
  description = "Mapa de servidores y AZ's"

  # El tipo es un mapa de objetos
  type = map(object({
    nombre = string,
    az = string
  }))

  default = {
    "srv1" = { nombre = "server1", az = "a" },
    "srv2" = { nombre = "server2", az = "b" },
    # Al estar refactorizado, agrego otro server simplemente así y todo se replica
    "srv3" = { nombre = "server3", az = "c" },
  }
}