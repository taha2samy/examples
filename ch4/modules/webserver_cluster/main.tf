




resource "aws_launch_template" "template_instance" {
  name_prefix            = "my-launch-template-"
  image_id               = data.aws_ami.linux_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh_http_ec2.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl enable httpd
systemctl start httpd

# We are using a 'Here Document' to write a full HTML file easily
cat > /var/www/html/index.html <<EOT
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Terraform Deployed Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        div { border: 1px solid #ccc; padding: 20px; display: inline-block; }
    </style>
</head>
<body>
    <div>
        <h1>Hello from a full Apache (httpd) Server!</h1>
        <hr>
        <h2>Database Connection Info:</h2>
    </div>
</body>
</html>
EOT
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
  health_check_grace_period = 5000

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
