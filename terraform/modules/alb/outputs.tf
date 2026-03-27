############################################
# ALB outputs
############################################

# Public DNS name of the load balancer
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

# Target Group ARN
# Used by compute (ASG) module
output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

# ALB Security Group ID
# Used by compute module to allow inbound 8000
output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}

output "subnet_ids" {
  value = var.subnet_ids
}
