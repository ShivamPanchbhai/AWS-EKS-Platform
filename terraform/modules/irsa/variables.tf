#############################
# OIDC Provider ARN
# Output from EKS cluster
# Used for IRSA trust policies
#############################

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS cluster"
  type        = string
}

#############################
# OIDC Provider URL
# Output from EKS cluster
# Used for IRSA condition matching
#############################

variable "oidc_provider_url" {
  description = "OIDC provider URL from EKS cluster (without https://)"
  type        = string
}