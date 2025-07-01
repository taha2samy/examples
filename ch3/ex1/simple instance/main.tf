provider "aws" {
  
region = "eu-west-1"

}
terraform {
  backend "s3" {
    key            = "simple_app/terraform.tfstate"
  }
}
resource "aws_vpc" "main_vpc" {
  
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
    map_public_ip_on_launch = true
  tags = {
    Name = "my-subnet"
  }
}

data "aws_ami" "ami_latest" {
  
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
}

resource "tls_private_key" "ec2_key" {
  
  algorithm = "RSA"
  rsa_bits  = 2048

  
}
resource "local_file" "ec2_key_pair" {
  
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/ec2_key.pem"
  
}
resource "aws_key_pair" "ec2_key_pair" {
  
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
  
  tags = {
    Name = "my-ec2-key-pair"
  }
}

resource "aws_security_group" "enable_ssh" {
  vpc_id = aws_vpc.main_vpc.id
  name        = "allow_ssh"
  description = "Allow SSH access"
  
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "ec2" {
    ami           = data.aws_ami.ami_latest.id
    instance_type = "t2.micro"
    subnet_id     = aws_subnet.public_subnet.id
    associate_public_ip_address = true
    key_name      = aws_key_pair.ec2_key_pair.key_name
    vpc_security_group_ids = [aws_security_group.enable_ssh.id]
    tags = {
        Name = "my-ec2-instance"
    }
  
}



resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "my-vpc-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"        
    gateway_id = aws_internet_gateway.main_igw.id 
  }

  tags = {
    Name = "my-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}
