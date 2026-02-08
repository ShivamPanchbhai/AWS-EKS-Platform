# ECR repository URL
# Used by compute to pull Docker images
output "repository_url" {
  value = aws_ecr_repository.ehr.repository_url
}
