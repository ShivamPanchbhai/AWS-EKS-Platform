########################################################
# BOOTSTRAP LAYER
# This layer creates foundational resources required
# before CI/CD can run:
# - GitHub OIDC provider
# - GitHub IAM deploy role
# - S3 backend bucket (Terraform state)
#
# This stack runs locally only (one-time setup).
########################################################

terraform {
  # Define required provider versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# AWS Provider Configuration
# This uses your local AWS credentials.
provider "aws" {
  region = "ap-south-1"
}

########################################################
# GitHub OIDC Provider
# Establishes trust between AWS and GitHub Actions
########################################################

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

########################################################
# GitHub Actions Deploy Role
# This role will be assumed via OIDC from your repo
########################################################

resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:ShivamPanchbhai/*"
          }
        }
      }
    ]
  })
}

########################################################
# Attach Administrator policy (temporary for simplicity)
# We will restrict this later for least privilege.
########################################################

resource "aws_iam_role_policy_attachment" "github_admin_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

########################################################
# Terraform State Bucket
# Stores remote Terraform state for infra layer
########################################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = "shivam-terraform-state-306991549269"

  force_destroy = false

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "bootstrap"
  }
}

# Enable versioning (critical for state recovery)
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

