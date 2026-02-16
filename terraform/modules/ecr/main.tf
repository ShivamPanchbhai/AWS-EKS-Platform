############################################
# ECR Repository
############################################
resource "aws_ecr_repository" "repo" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"  # Prevent tag overwrite

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.repository_name
  }
}

############################################
# Lifecycle Policy
# - Keep max 5 images
# - Expire images older than 30 days
############################################
resource "aws_ecr_lifecycle_policy" "policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [

      # Rule 1: Keep only last 5 images
      {
        rulePriority = 1
        description  = "Keep only last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = [""]    # applies to all tags
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },

      # Rule 2: Expire images older than 30 days
      {
        rulePriority = 2
        description  = "Expire images older than 30 days"
        selection = {
          tagStatus   = "tagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

############################################
# Output repository URL
############################################
output "repository_url" {
  value = aws_ecr_repository.repo.repository_url
}
