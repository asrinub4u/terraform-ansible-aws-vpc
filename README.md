# Terraform-Ansible-AWS-Nginx

![terraform](https://raw.githubusercontent.com/rahulwaykos/terraform-ansible-aws/main/code/image.png)

In this blog, we are going to deploy Nginx Server on AWS instance by using Terraform and Ansible. Before dive into actual process lets look at some basics.

## What is Terraform?
Terraform is an open-source infrastructure as code software tool created by HashiCorp. It is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can manage existing and popular service providers as well as custom in-house solutions. Terraform manages external resources such as public cloud infrastructure, private cloud infrastructure, network appliances, software as a service, and platform as a service with providers. In this blog we are going to manage resources of Public Cloud- AWS.

## What is Ansible?
Ansible is an open-source automation tool, or platform, used for IT tasks such as configuration management, application deployment, intraservice orchestration, and provisioning. Automation simplifies complex tasks, not just making developers’ jobs more manageable but allowing them to focus attention on other tasks that add value to an organization. In other words, it frees up time and increases efficiency. After deploying AWS instance with the help of Terraform, we are going to configure Nginx server using Ansible.

## What can be managed using Terraform?
Terraform supports 100+ providers, allowing you to easily manage resources no matter where they are located like public cloud services, on-prem infrastructures etc. You can check it [here](https://registry.terraform.io/browse/providers).  

## Best practices
Before commencing lets look at best practices for using terraform.

- ### File Structure
When we start learning we put every resource definition, variable, and output in a single file. This is very simple when you are learning and have nothing more complex infrastructure to manage. But in production things get complicated. Code gets more complex which makes hard to read and manage. Terraform, we must follow a proper directory structure to take care of the complexities that may occur in the project. It would be best if we had separate directories for different purposes.
```
$ tree project/
project/
├── prod
│ ├── main.tf
│ ├── outputs.tf
│ └── variables.tf
```
- ### Naming
Naming conventions are used in Terraform to make things easily understandable. Following are few practices using naming convention
- Only use lowercase letters and numbers.
- Use _ (underscore) instead of - (dash) in all: resource names, variable names, outputs etc.
If we follow this it will easy for us to understand the code.

- ### Providers
It is strongly suggested to use official Terraform providers modules available. Using these modules in terraform registry will definately saves time. All we need is to change as per our need. Most providers in Terraform require us to provide valid configuration parameters so it can manipulate resources. For example, the  AWS provider needs an access key/secret and a region so it can access our account and execute tasks. 
- Using Variables to Configure a Provider

In this approach, we define a project variable for every required provider parameter:
```
variable "aws_region" {
  type = string
}
variable "aws_access_key" {
  type = string
}
variable "aws_secret_key" {
  type = string
}
```
Now, we use them in our provider declaration:
```
provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
```
- ### State Management
Terraform state files usually contain sensitive information, so we must take proper measures to secure it. Let's take a look at a few of them:
- Always use an ignore rule for `*.tfstate` files in our version control configuration. For Git, we can always exclude this by using .gitignore file
- Use of remote backend instead of using local backend. We will see this in detail later.

- ### Latest Version
Terraform community is very active, and the release of new functionalities happens frequently. It is recommended to stay on the latest version of Terraform as in when a new major release happens. You can easily upgrade to the latest version

### Pre-requisites:
Before you begin, you need to have following:
- Terraform and Ansible installed
- AWS Account (We need access-key, secret and if required-token to access the AWS resources)

### Let's Do It!!

To make it simple and easy to understand I have already created VPC and key pair. Lets look at terraform main configuration file:
- #### main.tf
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
A provider in Terraform is responsible for the lifecycle of a resource: create, read, update, delete. An example of a provider is AWS, which can manage resources of type `aws_instance` `aws_security_group`. Terraform has plug-ins for each provider, and we need to download it before going to work with any cloud with Terraform by issuing the following command `terraform init` and it will download the necessary plug-ins for AWS. To make code simple and small, above file does not contain aws creadentials as described in best practices. Instead I have configured aws cli here. By default, terraform will look ~/.aws/credentials file first.

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

### Backend
Now we have our infrastructure, all details about infra as configuration is stored in state files. This state is used by Terraform to map real world resources to our configuration, keep track of metadata, and to improve performance for large infrastructures. A "backend" in Terraform determines how state is loaded and how an operation such as apply is executed. 
- If a configuration includes no backend block, Terraform defaults to using the `local` backend, which performs operations on the local system and stores state as a plain file in the current working directory.
- #### S3 as backend
To store the terraform state files in AWS S3 bucket, first we are going to create bucket and the configure it as backend. This is seperate example, if have to store above example state files, we have to backend block in main.tf.
```
provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "state_tf" {
  bucket = "terraform_bucket"
  #We can see the full revision history of our state files with versioning
  versioning {
    enabled = true
  }
  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
 }
 
 terraform {
  backend "s3" {
    bucket         = "terraform_bucket"
    key            = "s3/terraform.tfstate"
    region         = "us-east-1"
 
```
Run `terraform init` to download the provider code and then run `terraform apply` to deploy. Once everything is deployed, you will have an S3 bucket as backed to store terraform state file.

Hope you enjoyed blog. Happy Terraform-ing!!!
