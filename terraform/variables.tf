############################################################
# GLOBAL VARIABLES
############################################################

variable "region" {
  description = "AWS region for all resources"
  default     = "ap-south-1"
}

############################################################
# NODE GROUP SCALING
# Single source of truth for app node group max size
# Used by both EKS module (ASG max_size) and CloudWatch module
# (near-max-capacity alarm threshold)
############################################################

variable "node_max_size" {
  description = "Maximum number of worker nodes in the app node group"
  type        = number
  default     = 10
}