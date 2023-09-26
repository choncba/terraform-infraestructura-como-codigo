variable "server_port" {
  description = "Puerto de los servidores"
  type = number
  default = 8080
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