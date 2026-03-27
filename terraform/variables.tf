############################################################
# GLOBAL VARIABLES
############################################################

variable "region" {
  description = "AWS region for all resources"
  default     = "ap-south-1"
}

variable "image_tag" {
  description = "Docker image tag passed from CI/CD"
  type        = string
}
