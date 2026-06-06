############################################################
# POD IDENTITY MODULE VARIABLES
# Values passed in from root main.tf via module block
############################################################

# Name of the EKS cluster -- used in all addon and association resources
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

# Version of the Pod Identity Agent addon running as a DaemonSet on every node
variable "pod_identity_agent_version" {
  description = "Version of the EKS Pod Identity Agent addon"
  type        = string
  default     = "v1.3.10-eksbuild.2"
}

# IAM role ARN for EBS CSI driver -- passed from IAM module output
# Used in Pod Identity Association to allow EBS volume provisioning
variable "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  type        = string
}