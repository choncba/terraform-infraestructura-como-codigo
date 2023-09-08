# Curso de Terraform con AWS

## Entorno
- Instalar Terraform
- Instalar plugin de Terraform en VS Code

## Unidades
### 1 - Crear servidor EC2 - ./curso/1-EC2/main.tf
En main.tf
- Definir el [provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) y la región
```
provider "aws" {
  region = "us-east-1"
}
```
- Definir el [método de autenticación](hhttps://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
Si estoy logueado con SSO a aws, basta con definir la variable de entorno AWS_PROFILE con el perfil configurado:
```
export AWS_PROFILE=sandbox
```
- Definir el recurso a implementar
```
resource "aws_instance" "server1" {
  ami = "ami-053b0d53c279acc90" # Imagen del SO a utilizar, lo sacamos de la lista de instancias de la consola de aws
  instance_type = "t2.micro"    # Capacidad de la VM
}
```
- En el terminal, iniciar terraform 
```
terraform init
``` 
- Crear el plan
```
terraform plan
```
