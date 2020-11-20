variable "vpc_id" {
  default  = "vpc-0b5f4e71d693c1852"
}

variable "subnet_id" {
  default  = "subnet-0c4e6519a41fd5e60"
}

variable "ssh_user" {
  default  = "ubuntu"
}

variable "key_name" {
  default  = "devops"
}

variable "private_key_path" {
  default  = "~/terraform/devops.pem"
}
