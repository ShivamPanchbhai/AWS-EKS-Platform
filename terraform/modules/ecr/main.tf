# Reference existing ECR repository (do not manage it)
data "aws_ecr_repository" "ehr" {
  name = "ehr-service"
}

