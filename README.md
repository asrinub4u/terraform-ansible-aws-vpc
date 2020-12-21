# Terraform-Ansible-AWS-Nginx

![terraform](https://raw.githubusercontent.com/rahulwaykos/terraform-ansible-aws/main/code/image.png)

In this blog, we are going to deploy Nginx Server on AWS instance by using Terraform and Ansible. Before dive into actual process lets look at some basics.

## What is Terraform?
Terraform is an open-source infrastructure as code software tool created by HashiCorp. It is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can manage existing and popular service providers as well as custom in-house solutions. Terraform manages external resources such as public cloud infrastructure, private cloud infrastructure, network appliances, software as a service, and platform as a service with providers. In this blog we are going to manage resources of Public Cloud- AWS.

## What is Ansible?
Ansible is an open-source automation tool, or platform, used for IT tasks such as configuration management, application deployment, intraservice orchestration, and provisioning. Automation simplifies complex tasks, not just making developers’ jobs more manageable but allowing them to focus attention on other tasks that add value to an organization. In other words, it frees up time and increases efficiency. After deploying AWS instance with the help of Terraform, we are going to configure Nginx server using Ansible.

## What can be managed using Terraform?
Terraform supports 100+ providers, allowing you to easily manage resources no matter where they are located like public cloud services, on-prem infrastructures etc. You can check it !here[https://registry.terraform.io/browse/providers]. Primarily this consists of resources like virtual machines and DNS records. These 

### Pre-requisites:
Before you begin, you need to have following:
- Terraform and Ansible installed
- AWS Account (We need access-key, secret and if required-token to access the AWS resources)

### Let's Do It!!

To make it simple and easy to understand I have already created VPC and key pair. Lets look at terraform main configuration file:
#### main.tf
```
provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "nginx" {
  name   = "nginx_access"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nginx" {
  ami                         = "ami-0dba2cb6798deb6d8"
  subnet_id                   = var.subnet_id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.nginx.id]
  key_name                    = var.key_name

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key_path)
      host        = aws_instance.nginx.public_ip
    }
  }
  provisioner "local-exec" {
    command = "ansible-playbook  -i ${aws_instance.nginx.public_ip}, --private-key ${var.private_key_path} nginx.yaml"
  }
}

output "nginx_ip" {
  value = aws_instance.nginx.public_ip
}
```
Lets break down above code
- Provider: 
A provider in Terraform is responsible for the lifecycle of a resource: create, read, update, delete. An example of a provider is AWS, which can manage resources of type `aws_instance` `aws_security_group`. Terraform has plug-ins for each provider, and we need to download it before going to work with any cloud with Terraform by issuing the following command `terraform init` and it will download the necessary plug-ins for AWS.

- local-exec and remote-exec:
These two built in provisioners local-exec and remote-exec are required for Ansible to work in Terraform, as Terraform lacks the necessary native plug-ins. This is the workaround to invoke Ansible within the local-exec provisioner. That requires to configure the connection with the host, user, and private_key.

    * local-exec:
For Ansible, you can first run the Terraform, and output the IP addresses, then run ansible-playbook on those hosts. Snippet of code extracted from main.tf file.
```
provisioner "local-exec" {
    command = "ansible-playbook  -i ${aws_instance.nginx.public_ip}, --private-key ${var.private_key_path} nginx.yaml"
  }
```
- Connection: 
Terraform uses a number of defaults when connecting to a resource, but these can be overridden using a connection block in either a resource or provisioner. Any connection information provided in a resource will apply to all the provisioners, but it can be scoped to a single provisioner as well.
Private key is .pem file downloaded from AWS.

In above code there are some parameters starting with `var.---`. These are the variables used. The default values of these configured in variable.tf file. 
- Variable.tf
```
variable "vpc_id" {
  default  = "vpc-0b5f4e71dc1852"
}

variable "subnet_id" {
  default  = "subnet-0c4e6511fd5e60"
}

variable "ssh_user" {
  default  = "ubuntu"
}

variable "key_name" {
  default  = "devops"
}

variable "private_key_path" {
  default  = "~/terraform-ansible-aws/code/devops.pem"
}
```
Now lets look at ansible playbook to configure aws instance as Nginx Server. This playbook install required packages and ensures the service is up and running.
- nginx.yaml
```
---
- name: Install Nginx Server
  hosts: all
  remote_user: ubuntu
  become: yes
  tasks: 
  - name: Ensure Nginx is at the latest version
    apt:
      name: nginx
      state: latest
  - name: Make sure Nginx service is running
    systemd:
      state: started
      name: nginx
      
 ```
 And I also configured `ansible.cfg` in same directory to set host key checking false. We can also pass this with ansible-playbook command. 
 Now we are all set to run terraform commands. As said earlier, to download the provider we need to run following command:
 ``` 
 $ terraform init
 ```
After this we have to check what kind of resources are going to deploy. We can check this by
```
$ terraform plan 
```
Now we are going to apply these settings by
```
$ terraform apply 
```
When process is complete, it will give us output as `nginx_ip`. which we configured to get in main.tf file. 
```
output "nginx_ip" {
  value = aws_instance.nginx.public_ip
}
```
From this ip you can see default Nginx Page since we have not configured any index page.

Hope you enjoyed blog. Happy Terraform-ing!!!
