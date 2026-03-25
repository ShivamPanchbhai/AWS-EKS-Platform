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

  ##########################################################
  # Remote Backend (Created via Bootstrap Layer)
  # Stores Terraform state in S3
  ##########################################################
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
# NETWORKING (Using Default VPC for Simplicity)
############################################################

# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch all subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################################
# AMI LOOKUP (Amazon Linux 2023)
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
# MODULE: ECR (Container Registry)
############################################################

# Creates:
# - Immutable ECR repository
# - Lifecycle policies
# - Scan on push
module "ecr" {
  source = "./modules/ecr"

  repository_name = "ehr-service"
}

############################################################
# MODULE: IAM (EC2 Runtime Role)
############################################################

# Creates:
# - EC2 runtime IAM role
# - Instance profile
# - ECR pull permissions
# - SSM permissions
module "iam" {
  source = "./modules/iam"
}

############################################################
# MODULE: ACM (SSL Certificate)
############################################################

# Creates:
# - ACM certificate
# - DNS validation records
module "acm" {
  source      = "./modules/acm"
  domain_name = "shivam.store"
}

############################################################
# SECURITY GROUP: Allow Prometheus to collect metrics
############################################################

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  description = "Allows monitoring server to fetch metrics from app instances"
  vpc_id      = data.aws_vpc.default.id

  ##########################################################
  # INBOUND RULE
  ##########################################################
  ingress {
    description = "Allow Prometheus server to access Node Exporter (metrics)"

    from_port   = 9100          # Node Exporter runs on this port
    to_port     = 9100
    protocol    = "tcp"

    # For now: allow from anywhere (easy setup)
    # Later: restrict only to monitoring instance
    cidr_blocks = ["0.0.0.0/0"]
  }

  ##########################################################
  # OUTBOUND RULE
  ##########################################################
  egress {
    description = "Allow app instances to respond back to Prometheus"

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    # Allow all outgoing traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
# MODULE: ALB (Ingress Layer)
############################################################

# Creates:
# - Application Load Balancer
# - Target group
# - HTTPS listener
# - Route53 alias record
module "alb" {
  source = "./modules/alb"

  vpc_id = data.aws_vpc.default.id
  service_name = "ehr"
  subnet_ids   = data.aws_subnets.default.ids

  certificate_arn = module.acm.certificate_arn
  domain_name     = "shivam.store"
}

############################################################
# MODULE: monitoring
# This block activates the monitoring module and passes required
# infrastructure details so Terraform can provision a dedicated EC2
# instance for Prometheus-based metric collection.
############################################################

module "monitoring" {

  # This tells Terraform:
  # "Go inside ./modules/monitoring and run whatever is defined there"
  # Without this block,  monitoring module will NEVER execute
  source = "./modules/monitoring"

  ############################################
  # Passing required inputs to the module
  ############################################

  # VPC where monitoring EC2 will be launched
  # (same network our app EC2)
  vpc_id = data.aws_vpc.default.id

  # Subnet where monitoring EC2 will sit
  # (decides networking + routing behavior)
  subnet_id = data.aws_subnets.default.ids[0]

  # Base OS image for monitoring EC2
  # (Amazon Linux in our case)
  ami_id = data.aws_ami.amazon_linux.id
}
############################################################
# MODULE: COMPUTE (Runtime Layer)
############################################################

# Creates:
# - Launch Template
# - Auto Scaling Group
# - EC2 security group
#
# Flow:
# CI/CD passes image_tag
# New tag → new LT version → ASG refresh
module "compute" {
  source = "./modules/compute"

  ##########################################################
  # Core runtime configuration
  ##########################################################
  ami_id     = data.aws_ami.amazon_linux.id
  image_tag  = var.image_tag
  region     = var.region

  ##########################################################
  # Networking
  ##########################################################
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  ##########################################################
  # Ingress integration
  ##########################################################
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id

  ##########################################################
  # IAM & ECR
  ##########################################################
  instance_profile_name = module.iam.instance_profile_name
  repository_url        = module.ecr.repository_url

  ##########################################################
  # Logical service name
  ##########################################################
  service_name = "ehr"

  ##########################################################
  # prometheus
  ##########################################################
   prometheus_sg_id = aws_security_group.prometheus_sg.id
}
