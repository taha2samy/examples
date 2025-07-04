
output "alb_dns_name" {
  value       = aws_lb.load_balancer.dns_name
  description = "The domain name of the load balancer"
}

output "aws_internet_gateway_id" {
  value       = aws_internet_gateway.main.id
  description = "The ID of the Internet Gateway"
}