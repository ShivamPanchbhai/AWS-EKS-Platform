#############################
# Outputs for IAM module
#############################

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_runtime.name
}

output "prometheus_instance_profile_name" {
  value = aws_iam_instance_profile.prometheus.name
}

output "prometheus_role_name" {
  value = aws_iam_role.prometheus.name
}
