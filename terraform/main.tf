############################################
# Terraform core configuration
############################################
terraform {

  # Define required providers and versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  # Remote backend for Terraform state
  # State is stored centrally in S3
  backend "s3" {
  bucket = "shivam-terraform-state-306991549269"
  key    = "ec2/terraform.tfstate"
  region = "ap-south-1"
}
}


############################################
# AWS provider configuration
############################################
provider "aws" {
  # All resources will be created in this region
  region = "ap-south-1"
}

############################################
# Networking (default VPC + subnets)
############################################

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# All subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################
# Data sources
############################################

# Lookup the latest Amazon Linux 2023 AMI
# This is used by the Launch Template later
data "aws_ami" "amazon_linux" {

  # Always fetch the most recent matching AMI
  most_recent = true

  # Official Amazon-owned AMIs only
  owners = ["amazon"]

  # Filter to Amazon Linux 2023 x86_64 images
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################################
               # Modules
############################################

############################################
               # ECR
############################################

# Creates an immutable ECR repository for Docker images
module "ecr" {
  source = "./modules/ecr"

repository_name = "ehr-service"
}

############################################
             # Compute
############################################

# Creates EC2 compute infrastructure:
# - Launch Template

# The module receives:

# - AMI ID from root (dynamic lookup)
# - Docker image tag from CI/CD (Git commit SHA)

# Any change to image_tag results in:
# - New Launch Template version
# - ASG instance refresh

module "compute" {
  source = "./modules/compute"

  # Amazon Linux AMI passed from root data source
  ami_id = data.aws_ami.amazon_linux.id

  # Docker image tag (Git commit SHA) injected by CI/CD
  image_tag = var.image_tag

# Subnets where ASG should launch instances
  subnet_ids = data.aws_subnets.default.ids

  # ALB Target Group ARN
  target_group_arn = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  vpc_id = data.aws_vpc.default.id
  service_name = "ehr"
  instance_profile_name = module.iam.instance_profile_name
  region        = var.region
  repository_url = module.ecr.repository_url
}

############################################
                 # ALB
############################################
# Creates:
# - Application Load Balancer
# - Target Group
############################################

module "alb" {
  source          = "./modules/alb"
  service_name    = "ehr"
  vpc_id          = var.vpc_id
  subnet_ids      = var.public_subnet_ids
  certificate_arn = module.acm.certificate_arn   # ACM output used here
  domain_name     = "shivam.store"
}

#############################
            # IAM
#############################

module "iam" {
  source = "./modules/iam"
}

#############################
            # ACM
#############################
module "acm" {
  source      = "./modules/acm"
  domain_name = "shivam.store"
}

