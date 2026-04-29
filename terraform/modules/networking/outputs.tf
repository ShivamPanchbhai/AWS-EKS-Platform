output "vpc_id" {
  description = "VPC ID consumed by all other modules"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block consumed by security groups"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS worker nodes"
  value       = aws_subnet.private[*].id
}