variable "ami_id" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "service_name" {
  type = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "region" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "prometheus_sg_id" {
  description = "Security group for Prometheus access"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of VPC for internal access"
  type        = string
}

