############################################################
# IAM MODULE OUTPUTS
# These are consumed by other modules via module references
# e.g. module.iam.eks_cluster_role_arn
############################################################

# Passed to EKS module -- attached to aws_eks_cluster as the control plane role
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

# Passed to EKS module -- attached to aws_eks_node_group for worker node permissions
output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}

# Passed to EKS module -- used by EBS CSI driver addon to manage EBS volumes
output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}