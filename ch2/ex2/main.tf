terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

variable "server_port" {
  description = "The port on which the server will run"
  default     = 80
  type        = number
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "ec2_key_pair_pem" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "${path.module}/ec2_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

data "aws_ami" "linux_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "allow_ssh_http_ec2" {
  name        = "allow_ssh_http_ec2"
  description = "Allow SSH and HTTP access to EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_http_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow-ssh-http-ec2"
  }
}

resource "aws_security_group" "allow_http_lb" {
  name        = "allow_http_lb"
  description = "Allow HTTP access to the Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow-http-lb"
  }
}

resource "aws_launch_template" "template_instance" {
  name_prefix   = "my-launch-template-"
  image_id      = data.aws_ami.linux_ami.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name
  
  vpc_security_group_ids = [aws_security_group.allow_ssh_http_ec2.id]

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from Terraform and Auto Scaling Group!</h1>" > /var/www/html/index.html
EOF
)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "auto_scale_instances" {
  launch_template {
    id      = aws_launch_template.template_instance.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.target_group.arn]
  min_size           = 1
  max_size           = 10
  desired_capacity   = 4
  
  health_check_type         = "ELB" 
  health_check_grace_period = 1000

  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tag {
    key                 = "Name"
    value               = "AutoScaledInstance"
    propagate_at_launch = true
  }

}

resource "aws_lb" "load_balancer" {
  name                       = "my-load-balancer"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.allow_http_lb.id]
  subnets                    = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  enable_deletion_protection = false

  tags = {
    Name = "my-load-balancer"
  }


}

resource "aws_lb_listener" "listeners" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = var.server_port
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "my-target-group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = {
    Name = "my-target-group"
  }
}

resource "aws_lb_listener_rule" "listeners_rule" {
  listener_arn = aws_lb_listener.listeners.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  tags = {
    Name = "listener-rule"
  }
}

output "alb_dns_name" {
  value       = aws_lb.load_balancer.dns_name
  description = "The domain name of the load balancer"
}

output "aws_internet_gateway_id" {
  value       = aws_internet_gateway.main.id
  description = "The ID of the Internet Gateway"
}