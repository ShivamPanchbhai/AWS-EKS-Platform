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
# Pod Identity handles pod-level AWS access
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
# MODULE: POD IDENTITY
# Replaces IRSA for pod-level AWS access
# Installs Pod Identity Agent as EKS addon (DaemonSet)
# Links IAM roles to Kubernetes service accounts directly
# No OIDC provider or trust policy complexity needed
############################################################

module "pod_identity" {
  source = "./modules/pod-identity"

  cluster_name = module.eks.cluster_name
}