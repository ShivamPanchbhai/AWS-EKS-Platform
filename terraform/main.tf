############################################################
# TERRAFORM CORE CONFIGURATION
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  backend "s3" {
    bucket = "shivam-terraform-state-306991549269"
    key    = "ec2/terraform.tfstate"
    region = "ap-south-1"
  }
}

############################################################
# AWS PROVIDER
############################################################

provider "aws" {
  region = var.region
}

############################################################
# NETWORKING (Default VPC)
############################################################

data "aws_vpc" "default" {
  default = true
}

# All subnets (used for compute)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################################
# AMI LOOKUP
############################################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################################################
# MODULE: ECR
############################################################

module "ecr" {
  source = "./modules/ecr"

  repository_name = "ehr-service"
}

############################################################
# MODULE: IAM
############################################################

module "iam" {
  source = "./modules/iam"
}

############################################################
# MODULE: ACM
############################################################

module "acm" {
  source      = "./modules/acm"
  domain_name = "shivam.store"
}

############################################################
# MODULE: ALB (PUBLIC ENTRY LAYER)
############################################################

module "alb" {
  source = "./modules/alb"

  vpc_id       = data.aws_vpc.default.id
  service_name = "ehr"

  # These are PUBLIC subnets (ALB requires public)
  subnet_ids = data.aws_subnets.default.ids

  certificate_arn = module.acm.certificate_arn
  domain_name     = "shivam.store"
}

############################################################
# MODULE: MONITORING
############################################################

module "monitoring" {

  source = "./modules/monitoring"

  vpc_id = data.aws_vpc.default.id

  ##########################################################
  # KEY FIX: reuse ALB subnet (already public)
  ##########################################################
  subnet_id = data.aws_subnets.default.ids[0]

  ami_id = data.aws_ami.amazon_linux.id

  prometheus_instance_profile_name = module.iam.prometheus_instance_profile_name
  prometheus_role_name             = module.iam.prometheus_role_name
}

############################################################
# MODULE: COMPUTE (APP LAYER)
############################################################

module "compute" {
  source = "./modules/compute"

  ami_id    = data.aws_ami.amazon_linux.id
  region    = var.region

  ##########################################################
  # Networking
  ##########################################################
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  ##########################################################
  # ALB integration
  ##########################################################
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id

  ##########################################################
  # IAM + ECR
  ##########################################################
  instance_profile_name = module.iam.instance_profile_name
  repository_url        = module.ecr.repository_url

  ##########################################################
  # Service
  ##########################################################
  service_name = "ehr"

  ##########################################################
  # Internal VPC access (for monitoring scraping)
  ##########################################################
  vpc_cidr = data.aws_vpc.default.cidr_block
}
