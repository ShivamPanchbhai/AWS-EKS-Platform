output "repository_url" {
  value = data.aws_ecr_repository.ehr.repository_url
}

output "repository_arn" {
  value = data.aws_ecr_repository.ehr.arn
}
