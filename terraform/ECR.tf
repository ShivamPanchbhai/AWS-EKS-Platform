resource "aws_ecr_repository" "ehr" {
  name                 = "ehr-service"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
