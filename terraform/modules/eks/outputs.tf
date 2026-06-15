############################################################
# EKS MODULE OUTPUTS
# Outputs are how modules communicate.
############################################################

# Cluster name -- consumed by Pod Identity module for addon and association resources
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

# Cluster API endpoint -- used by kubectl/Helm/ArgoCD to connect to the cluster
output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

# Cluster CA certificate -- used to verify TLS when connecting to the cluster
output "cluster_ca_certificate" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

# Node group security group -- referenced for ALB to pod traffic rules
output "node_security_group_id" {
  value = aws_security_group.node_group.id
}

# ASG name backing the app node group -- consumed by CloudWatch module
# to set up the near-max-capacity alarm
output "node_group_asg_name" {
  value = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
}