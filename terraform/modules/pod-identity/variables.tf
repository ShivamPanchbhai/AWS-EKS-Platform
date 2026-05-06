variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "pod_identity_agent_version" {
  description = "Version of the EKS Pod Identity Agent addon"
  type        = string
  default     = "v1.3.10-eksbuild.2"
}