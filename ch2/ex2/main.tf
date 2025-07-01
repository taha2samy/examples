variable "region" {
    description = "The availability zone to deploy resources in"
    default     = "eu-west-1"
    type        = string
}
provider "aws" {
  
  region = var.region
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

resource "aws_vpc" "home" {
  
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.home.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
}
resource "aws_security_group" "allow_ssh" {

  
  name        = "allow_ssh"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.home.id

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
data "aws_ami" "ami_latest" {
  
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
}

resource "aws_launch_template" "ec2_launch_template" {
  
  name_prefix   = "my-ec2-launch-template-"
  image_id      = data.aws_ami.ami_latest.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
    lifecycle {
    create_before_destroy = true
  }
  
}


resource "aws_autoscaling_group" "auto_scaling_group_terraform" {
  
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"

  }

  min_size            = 2
  max_size            = 6
  desired_capacity    = 4
  vpc_zone_identifier = [aws_subnet.my_subnet.id]
  health_check_type  = "EC2"
  health_check_grace_period = 300
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.home.id
  tags = {
    Name = "my-vpc-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.home.id

  route {
    cidr_block = "0.0.0.0/0"        
    gateway_id = aws_internet_gateway.main_igw.id 
  }


}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

output "ip" {
  
  value = aws_autoscaling_group.auto_scaling_group_terraform.id
}