############################################################
# CLOUDWATCH MODULE VARIABLES
############################################################

# Name of the ASG backing the app node group
# Comes from EKS module output
variable "asg_name" {
  description = "ASG name for the app node group"
  type        = string
}

# Max size of the node group -- used to compute the 95% threshold
variable "max_size" {
  description = "Max size of the app node group ASG"
  type        = number
}

# Email address to receive SNS notifications
variable "alarm_email" {
  description = "Email address for capacity alert notifications"
  type        = string
}