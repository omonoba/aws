variable "region" {
  default = "us-west-2"
}

# Amazon Linux AMIs (x64)
variable "aws_amis" {
  default = {
    eu-west-2 = "ami-e98f9b8d"
    eu-west-1 = "ami-1a962263"
    us-east-1 = "ami-55ef662f"
    us-west-2 = "ami-e689729e"
    ca-central-1 = "ami-32bb0556"
  }
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "subnet_cidr" {
  type = "list"
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 80
}

variable "ssh_port" {
  default = 22
}

# Declare the data source
data "aws_availability_zones" "azs" {}
