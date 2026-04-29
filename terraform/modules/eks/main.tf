############################################################
# EKS CLUSTER
############################################################

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true

    security_group_ids = [aws_security_group.cluster.id]
  }

  ############################################################
  # Enable EKS control plane logging
  # Useful for auditing and debugging
  ############################################################
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [var.eks_cluster_role_arn]

  tags = {
    Name = var.cluster_name
  }
}

############################################################
# OIDC PROVIDER
# Enables IRSA (IAM Roles for Service Accounts)
# Pods assume IAM roles without hardcoded credentials
############################################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

############################################################
# CLUSTER SECURITY GROUP
# Controls traffic to EKS control plane
############################################################

resource "aws_security_group" "cluster" {
  name   = "${var.cluster_name}-cluster-sg"
  vpc_id = var.vpc_id

  # Allow worker nodes to talk to control plane
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

############################################################
# NODE GROUP SECURITY GROUP
# Controls traffic to worker EC2s
############################################################

resource "aws_security_group" "node_group" {
  name   = "${var.cluster_name}-node-sg"
  vpc_id = var.vpc_id

  # Nodes talk to each other (pod to pod)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Control plane to nodes
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # ALB to pods (app port)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus scraping Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

############################################################
# MANAGED NODE GROUP
# Worker EC2s managed by EKS
# Runs in private subnets
############################################################

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.eks_node_group_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  ############################################################
  # Enforce IMDSv2 on worker nodes
  # Same security standard as existing EC2 setup
  ############################################################
  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  ############################################################
  # Rolling update strategy
  # Same immutable deployment mindset as existing ASG
  ############################################################
  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}

############################################################
# LAUNCH TEMPLATE FOR NODE GROUP
# Enforces IMDSv2 on worker nodes
# Mirrors security standard from existing EC2 setup
############################################################

resource "aws_launch_template" "node_group" {
  name = "${var.cluster_name}-node-lt"

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name       = "${var.cluster_name}-node"
      Monitoring = "node-exporter"
    }
  }
}