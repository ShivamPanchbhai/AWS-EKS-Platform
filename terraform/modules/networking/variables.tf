############################################################
# VPC CIDR
############################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

############################################################
# PUBLIC SUBNET CIDRS
# One per AZ
############################################################

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

############################################################
# PRIVATE SUBNET CIDRS
# One per AZ
############################################################

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

############################################################
# AVAILABILITY ZONES
############################################################

variable "availability_zones" {
  description = "List of AZs to deploy subnets into"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

############################################################
# SERVICE NAME
############################################################

variable "service_name" {
  description = "Used for naming all networking resources"
  type        = string
}

############################################################
# CLUSTER NAME
# Required for EKS subnet tags so the Load Balancer
# Controller can discover the right subnets
############################################################

variable "cluster_name" {
  description = "EKS cluster name used for subnet tagging"
  type        = string
}