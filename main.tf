provider "aws" {
    region = "eu-west-2"
    access_key = "AKIATE6YVMDART4FHR7L"
    secret_key = "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"
} 

resource "aws_key_pair" "ec2_instance"{
    key_name  = "testing-ansible"
    public_key = file("/Users/larteyelvis/.ssh/id_rsa.pub")
}

variable "keypem" {
    default = "testing-ansible"
}

variable "private_key_loc" {
    description = "Location of the private key file."
    type        = string
    default     = "/Users/larteyelvis/.ssh/id_rsa"
}

variable "inventory" {
    description = "Location of the inventory_file"
    type        = string 
    default     = "./inventory.yml"
  
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_instance" "main_instance" {
    ami           = "ami-0015a39e4b7c0966f"
    instance_type = "t3.micro"
    associate_public_ip_address = true
    key_name = aws_key_pair.ec2_instance.id
    security_groups = [aws_security_group.allow_ssh.name]
    count = 2

    provisioner "remote-exec" {
        inline = ["echo 'Wait until SSH is ready.'"]

        connection {
          type = "ssh"
          user = "ubuntu"
          private_key = file("${var.private_key_loc}")
          host = "${self.public_ip}"
        }
    }

    tags = {
      "Environment" = "dev"
    }
}

resource "local_file" "ansible_inventory"{
    content = templatefile("${path.module}/templates/inventory.tpl",
      {
        instances = aws_instance.main_instance.*.public_ip
      }
    )

    filename = "${var.inventory}"

    depends_on = [aws_instance.main_instance]
}

resource "null_resource" "ansible_exec" {

  depends_on = [local_file.ansible_inventory]
  provisioner "local-exec"{
    command = "ansible-playbook --inventory ${var.inventory} --private-key ${var.private_key_loc} nginx.yaml"
  }
}

output "instance_ip" {
  value = aws_instance.main_instance.*.public_ip  
}