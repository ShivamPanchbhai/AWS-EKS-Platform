############################################################
# IAM MODULE OUTPUTS
# These are consumed by other modules via module references
# e.g. module.iam.eks_cluster_role_arn
############################################################

# Legacy EC2 instance profile -- used by existing non-EKS EC2 setup
output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_runtime.name
}

# Legacy Prometheus instance profile -- used by existing non-EKS Prometheus setup
output "prometheus_instance_profile_name" {
  value = aws_iam_instance_profile.prometheus.name
}

# Legacy Prometheus role name -- used by existing non-EKS Prometheus setup
output "prometheus_role_name" {
  value = aws_iam_role.prometheus.name
}
