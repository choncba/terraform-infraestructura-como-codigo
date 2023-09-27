# Definimos el provider
provider "aws" {
  region = "us-east-1"
}

variable "users" {
  type = list(string)
  default = ["juan", "pedro", "carlos", "jose"]
}

# Creo usuarios de IAM de forma dinámica
resource "aws_iam_user" "usuarios" {
  # count = 2                         # Defino el Numero de recursos a crear
  count = length(var.users)           # Extraigo la cantidad de usuarios de la lista
  # name = "user${count.index}"       # Nombre dinámico con el indice
  name = "${var.users[count.index]}"  # Extraigo los nombres de una variable con el indice
}