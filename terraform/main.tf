############################################################
# TERRAFORM CORE CONFIGURATION
############################################################

terraform {

  ##########################################################
  # REQUIRED PROVIDERS
  # Declares which provider plugins Terraform needs, and the
  # version range allowed for each. Without this block,
  # Terraform wouldn't know which plugin to use for any
  # resource type in this project, or could silently grab an
  # unpredictable version
  ##########################################################
  
  required_providers {

    # AWS provider -- creates and manages every AWS resource
    # in this project (EKS, IAM, S3, CloudWatch, etc.). Without
    # it, none of the aws_* resources could exist at all.

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }

    # Kubernetes provider -- lets Terraform talk to the
    # cluster's own API directly, used for the StorageClass.
    # Without it, that resource has no provider to run against.

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }

    # Helm provider -- lets Terraform install Helm charts
    # directly, used for the ArgoCD release. Pinned to 3.x
    # without this provider, the helm_release resource has nothing to
    # run against.

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

  } # required_providers_ends
  
  ##########################################################
  # REMOTE STATE BACKEND
  # Tells Terraform to store its state file in this S3 bucket
  # instead of on whatever machine happens to run the apply.
  # This matters specifically because GitHub Actions runners
  # start fresh and empty every single run, with no memory of
  # anything created before. Without a remote backend, every
  # workflow run would have no record of existing resources
  # and would try to recreate everything from scratch, causing
  # duplicate-resource errors, or worse.
  ##########################################################

  backend "s3" {
    bucket = "shivam-terraform-state-306991549269"
    key    = "eks/terraform.tfstate"
    region = "ap-south-1"
  }

} # terraform_ends 

############################################################
# HELM PROVIDER CONFIGURATION
# Configures how the Helm provider actually connects to the
# cluster it needs to install charts into. Reuses the same
# cluster outputs and auth token the kubernetes provider
# already uses, rather than a kubeconfig file, since a fresh
# GitHub Actions runner wouldn't have one. Without this block,
# the helm_release resource wouldn't know which cluster to
# connect to, and apply would fail immediately.
############################################################

provider "helm" {
  kubernetes = {
    # API server endpoint -- without this, Helm has no address
    # to send requests to at all
    
    host                   = module.eks.cluster_endpoint

    # Cluster's CA certificate -- without this, TLS verification
    # fails, since there's no way to confirm it's actually
    # talking to the real cluster
    
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    # Short-lived auth token -- without this, every request gets
    # rejected as unauthenticated, regardless of a valid host
    # and certificate

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