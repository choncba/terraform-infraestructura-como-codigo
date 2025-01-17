# Curso de Terraform con AWS

## Entorno
- Instalar Terraform
- Instalar plugin de Terraform en VS Code
- Definir el [método de autenticación](hhttps://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
Si estoy logueado con SSO a aws, basta con definir la variable de entorno AWS_PROFILE con el perfil configurado:
## ***********************
```
export AWS_PROFILE=sandbox
```

## Unidades
### 1 - Crear servidor EC2 - ./curso/1-EC2/main.tf
En main.tf
- Definir el [provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) y la región
```
provider "aws" {
  region = "us-east-1"
}
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
- Aplicar los cambios
```
terraform apply
```
Esto crea la VM en AWS con Ubuntu, pero no hay nada en ejecución.
- Creamos un script de inicio para que levante un servidor web y muestre un mensaje dentro de resource en main.tf
```
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y busybox-static
              echo "Hola che culiao!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
```
- Aplicamos los cambios con terraform apply, terraform elimina la VM del punto anterior y recrea una nueva con el script de inicio.
- Ahora para poder alcanzar el servidor web, tenemos que crear un security group en main.tf
```
resource "aws_security_group" "terraform_sg" {
  name = "server1-sg"
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acceso al puerto 8080"
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
  }
```
Y asociar este security group a la EC2 agregando en la configuración de la instancia:
```
vpc_security_group_ids = [ aws_security_group.terraform_sg.id ]
```
- volvemos a aplicar los cambios con terraform apply.
- Si vamos a la instancia de la ec2 en la consola de aws, buscamos la DNS pública, la copiamos y vamos al puerto 8080
http://ec2-3-88-59-56.compute-1.amazonaws.com:8080/
Vemos el mensaje en el servidor web corriendo
- Podemos agregar tags, por ejemplo el nombre del servidor dentro de la definición de la instancia con:
```
  tags = {
    Name = "server1"
  }
```
- Finalmente liberamos los recursos con
```
terraform destroy
```

## Archivos complementarios 
### terraform.tfstate
Archivo JSON que nos muestra el estado de los recursos en AWS.
Si existen cambios entre esta configuración y el archivo main.tf, al ejecutar terraform apply se aplican.
### .terraform.lock.hcl
Control de versión de terraform. para actualizarlo podemos hacer
```
terraform init -upgrade
```
### .terraform
Carpeta donde se guardan plugins de providers

## Outputs
Son archivos de Terraform que nos permiten extraer información de los recursos creados en AWS sin necesidad de acceder a la consola de AWS desde el browser, por ejemplo, para saber la ip pública de nuestra instancia EC2.
- Creamos output.tf con los outputs deseados
- Hacemos terraform apply y luego de confirmar tenemos la salida:
```bash
Outputs:

dns_publica = "ec2-54-80-117-153.compute-1.amazonaws.com"
```

### 2 - Load Balancer - ./curso/2-LoadBalancer/main.tf
Creamos un load balancer que permita conectarme con 2 instancias EC2 idénticas dentro de la misma AZ (us-east-1), pero en datacenters distintos (1A y 1B) por redundancia. El LB dirigirá el tráfico por defecto a 1A, y a 1B en caso de que 1A no esté disponible. 
- Definimos 2 instancias EC2 igual que en el punto anterior con distinto nombre
- Mantenemos el mismo Security Group del punto anterior
Para poder asignar cada EC2 a una VPC en cada AZ, podemos seleccionar el id de la VPC deseada de la [consola de AWS](https://us-east-1.console.aws.amazon.com/vpc/home?region=us-east-1#vpcs:) y lo agregamos a la entrada de la instancia como 
```
subnet_id = "subnet-01e50bfb5f6a3c07a"
```
Otra forma de obtener información de los recursos de AWS que no fueron creados por Terraform, es usar un [datasource](https://registry.terraform.io/providers/hashicorp/aws/3.12.0/docs/data-sources/vpc).
```
data "aws_subnet" "az1" {
  # vpc_id = "AE-Media-VPC"
  availability_zone = "us-east-1a"
}
```
Y referenciando al mismo en la definición de la EC2
```
subnet_id = data.aws_subnet.az1.id
```
- Opcionalmente, modificamos los outputs.tf para obtener la información
- Aplicamos los cambios con
```
terraform init
terraform plan
terraform apply
```
- En main.tf creamos los recursos para el load balancer y su security group, de acuerdo a la [documentacion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
```
# Definimos el load balancer
resource "aws_lb" "alb" {
  load_balancer_type = "application"
  name = "servers-alb"
  # Security group del LB, no es el mismo de las EC2
  security_groups = [ aws_security_group.alb.id ]
  # Indicamos las subredes que alcanza el LB, reutilizando los datasource anteriores
  subnets = [ data.aws_subnet.az1.id, data.aws_subnet.az2.id ]
}

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
}
```
- Definimos un Target Group para las instancias EC2 de acuerdo a la [documentación](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)
```
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
```
- Definimos un attachment para asociar cada instancia EC2 al target group anterior
```
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
```
- Definimos un listener para el LB, que redirija el puerto 80 hacia el 8080
```
resource "aws_lb_listener" "alb-tg-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
   target_group_arn = aws_lb_target_group.alb-tg.arn
   type = "forward"  
  }
}
```
- Actualizo los outputs para que muestre el DNS público del LB
- Validamos y aplicamos los cambios
```
terraform validate
terraform apply
```

### 3 - Variables
Partiendo del ejemplo del load balancer, vamos a crear el archivo variables.tf, donde definimos las variables a utilizar en main.tf.
El valor asignado a esas variables puede darse de múltiples formas:
- Hacemos ```terraform apply``` nos aparecerá un prompt consultando por el valor que le queremos dar a cada variable.
- Por línea de comandos:
```
terraform plan -var="server_port=8080" -var="lb_port=80" -var="EC2_TYPE=t2.micro"
```
- Con un archivo .tfvars:
```
server_port=8080
lb_port=80
EC2_TYPE=t2.micro
```
Para usarlo hacemos: ```terraform apply -var-file="vars.tfvars```
- Con un archivo json:
```json
{
    "server_port": 8080,
    "lb_port": 80,
    "EC2_TYPE":"t2.micro"
}
```
* Si omitimos alguna de las variables en el archivo de configuración, terraform las consulta por consola
* Terraform levanta automáticamente cualquier archivo que tenga en el nombre '.tfvars' (ej: vars.tfvars.json) 
- Usando variables de entorno, las definimos `TF_VAR_<NOMBRE_DE_LA VARIABLE>`
Ejemplo: `TF_VAR_lb_port=80`
- Valores por defecto: Se agregan dentro de la definición de las variables en `variables.tf` con el tag `default`.
En este caso, si hacemos `terraform apply` sin ningún flag. utiliza valores por defecto
* Precedencia
- 1 Variables de entorno
- 2 *.tfvars
- 3 *. tfvars.json
- 4 *.auto.tfvars / *.auto.tfvars.json
- 5 flags -var / -var-file

### Variables dinámicas 
Podemos definir una variable con el tipo `any`. Se asignará a la variable el tipo que se le asigne, number, string, list, etc.
En el caso de listas `[any]` si ponemos distintos tipos, terraform convierte todos los elementos a string.

### Variables map
Permiten asociar pares key/value como un diccionario.
```
variable "UBUNTU_AMI" {
  description = "ID de imagen de Ubuntu segun región de AWS"
  type = map(string)
  default = {
    "us-east-1" = "ami-053b0d53c279acc90"
    "eu-west-1" = "ami-095df877cd67dfd34"
  }
  
}
```
Para instanciarla hacemos `var.UBUNTU_AMI["us-east-1"]`

### Validación
Nos permite validar valores de las variables mediante el bloque `validate` en la definicion de la variable.
```
variable "server_port" {
  description = "Puerto de los servidores"
  type = number
  default = 8080

  validation {
    condition = var.server_port >= 5000 && var.server_port <= 10000
    error_message = "Utilizar puertos entre 5000 y 10000"
  }
}
```

### 4 - Bucles
Terraform es un lenguaje declarativo, por lo que no posee bucles, para solucionarlo, disponemos de meta argumentos:
- count
- for_each
- depends_on
- provider
- lifecycle

* count
```
resource "aws_iam_user" "usuarios" {
  count = 2                         # Defino el Numero de recursos a crear
  name = "user${count.index}"       # Nombre dinámico con el indice
}
```
Esto creará 2 usuarios iam con el nombre user0 y user1.
```
# Itero una lista de usuarios y genero un recurso para cada uno
variable "users" {
  type = list(string)
  default = ["juan", "pedro", "carlos", "jose"]
}

resource "aws_iam_user" "usuarios" {
  count = length(var.users)           # Extraigo la cantidad de usuarios de la lista
  name = "${var.users[count.index]}"  # Extraigo los nombres de una variable con el indice
}
```
* for_each
Similar a count, especificamente para recorrer listas. La ventaja principal es que crea las keys con los valores de la lista, no la posición, por lo que el orden de los elementos no afecta.
```
resource "aws_iam_user" "users" {
  for_each = var.usr
  name = "${each.value}"
}
```
* for
Nos permite recorrer una lista
```
output "nombre_a_arn" {
  # value será un set de nombre: arn
  value = { for usuario in aws_iam_user.ejemplo : usuario.name => usuario.arn }
}

output "nombres_usuarios" {
  #value será una lista con los nombres de los usuarios
  value = [for usuario in aws_iam_user.ejemplo : usuario.name]
}
```
* Splat
Expresión que sirve para iterar sobre listas => [*]
```
output "nombres_usuarios" {
  #value será una lista con los nombres de los usuarios
  value = aws_iam_user.ejemplo[*].name
}
```

* Variables <b>*local*</b>
<br>Sirven para definir constantes, similar a una variable de entorno, y podemos referenciarla en cualquier otro archivo de terraform, siempre que estemos en la misma carpeta
```
# Las definimos
locals {
  region = "us-east-1"
}

* Las referenciamos:

reg = local.region

* tambien podemos combinar variables
locals {
  # a la variable var.ubuntu_ami["us-east-1"] la asignamos
  region  = "us-east-1"
  ami     = var.ubuntu_ami[local.region]
}

* Y luego podemos invocar
ami = local.ami
```

### 5 - Refactorizamos el LoadBalancer
Aplicamos los métodos anteriores para refactorizar y simplificar el código del loadbalancer. Tambien lo hacemos en los outputs
* Al quedar modular, si queremos agregar más servidores/AZ simplemente lo agregamos a la variable servers

### 6 - Módulos

