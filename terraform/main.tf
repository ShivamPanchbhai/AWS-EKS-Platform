############################################################
# TERRAFORM CORE CONFIGURATION
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }

  backend "s3" {
    bucket = "shivam-terraform-state-306991549269"
    key    = "eks/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
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
  ebs_csi_role_arn        = module.iam.ebs_csi_role_arn
  node_max_size           = var.node_max_size
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
  ebs_csi_role_arn = module.iam.ebs_csi_role_arn
}

############################################################
# MODULE: CLOUDWATCH
# SNS topic + alarm for app node group nearing max capacity
# Early warning so node_max_size can be raised before
# Cluster Autoscaler hits its ceiling
############################################################

module "cloudwatch" {
  source = "./modules/cloudwatch"

  asg_name    = module.eks.node_group_asg_name
  max_size    = var.node_max_size
  alarm_email = "panchbhaishivam@gmail.com"
}

############################################################
# EKS CLUSTER AUTH TOKEN
# Generates a short-lived token so Terraform can authenticate
# to the Kubernetes API using the kubernetes provider below
############################################################
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

############################################################
# KUBERNETES PROVIDER
# Lets Terraform manage K8s objects directly, not just AWS resources
# Auth uses EKS cluster endpoint + CA cert + the token above
############################################################
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

############################################################
# STORAGE CLASS (moved from ehr-app Helm chart)
# gp3 default class, used by kube-prometheus-stack for
# Prometheus and Grafana persistent EBS volumes
# depends_on ensures EBS CSI driver addon exists first
############################################################
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}

############################################################
# ARGOCD
# Installed via Terraform's Helm provider, same cluster
# nothing needed since ArgoCD's own default tolerations
# already keep it off the tainted monitoring node
############################################################
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.2.1"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [module.eks]
}