############################################################
# TERRAFORM CORE CONFIGURATION
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }

  backend "s3" {
    bucket = "shivam-terraform-state-306991549269"
    key    = "eks/terraform.tfstate"
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
# MODULE: NETWORKING
# Custom VPC replacing default VPC
# Public subnets for ALB, private subnets for EKS nodes
############################################################

module "networking" {
  source = "./modules/networking"

  service_name = "ehr"
  cluster_name = "ehr-eks-cluster"
}

############################################################
# MODULE: ECR
# Unchanged - EKS pulls from same registry
############################################################

module "ecr" {
  source = "./modules/ecr"

  repository_name = "ehr-service"
}

############################################################
# MODULE: ACM
# Unchanged - same TLS certificate
############################################################

module "acm" {
  source      = "./modules/acm"
  domain_name = "shivam.store"
}

############################################################
# MODULE: IAM
# EKS cluster role and node group role added
# IRSA roles moved to separate module below
############################################################

module "iam" {
  source = "./modules/iam"
}

############################################################
# MODULE: EKS
# Replaces compute module
# Worker nodes run in private subnets
############################################################

module "eks" {
  source = "./modules/eks"

  cluster_name            = "ehr-eks-cluster"
  vpc_id                  = module.networking.vpc_id
  vpc_cidr                = module.networking.vpc_cidr
  private_subnet_ids      = module.networking.private_subnet_ids
  eks_cluster_role_arn    = module.iam.eks_cluster_role_arn
  eks_node_group_role_arn = module.iam.eks_node_group_role_arn
}

############################################################
# MODULE: IRSA
# Runs after EKS because it needs OIDC provider outputs
# Creates IAM roles for Load Balancer Controller
# and External Secrets Operator pods
############################################################

module "irsa" {
  source = "./modules/irsa"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}