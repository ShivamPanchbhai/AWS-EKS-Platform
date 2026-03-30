############################################
# VPC ID
# Needed to launch the monitoring EC2 inside
# the correct network (same VPC as app)
############################################
variable "vpc_id" {}

############################################
# Subnet ID
# Decides in which subnet the monitoring EC2
# will be created (usually public/private subnet)
############################################
variable "subnet_id" {}

############################################
# AMI ID
# Base OS image for the monitoring EC2
# (Amazon Linux 2023 )
############################################
variable "ami_id" {}

variable "prometheus_instance_profile_name" {
  type = string
}

variable "prometheus_role_name" {
  type = string
}












