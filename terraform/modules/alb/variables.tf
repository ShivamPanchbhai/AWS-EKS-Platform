########################################################
# INPUT VARIABLES
########################################################

variable "service_name" {
  description = "Name prefix for ALB resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC where ALB will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN (from ACM module output)"
  type        = string
}

variable "domain_name" {
  description = "Public domain for DNS alias record"
  type        = string
}
