############################################################
# KEY VALUES REFERENCED IN THIS FILE
#
# 443        HTTPS port -- EKS control plane API server
# -1         AWS shorthand for "all protocols" (egress rules,
#            and the pod-to-pod ingress rule)
# 0.0.0.0/0  CIDR for "anywhere on the internet" (egress only)
# 0          from_port/to_port paired with protocol -1 means
#            "all ports" -- AWS convention, not a real port
# 1025       Start of the ephemeral port range AWS recommends
#            opening for control plane -> kubelet traffic
# 65535      End of that range, also the max possible port
#            number (16-bit limit)
# 8000       ehr-app's container port -- ALB routes here
# 9100       Node Exporter's metrics port -- Prometheus scrapes
#            this on every node
############################################################

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

  tags = {
    Name = var.cluster_name
  }
}

############################################################
# CLUSTER SECURITY GROUP
# Controls traffic to EKS control plane
############################################################

resource "aws_security_group" "cluster" {
  name   = "${var.cluster_name}-cluster-sg"
  vpc_id = var.vpc_id

  # Port 443 -- VPC-wide CIDR, not scoped to worker nodes
  # specifically (known gap, not yet tightened)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All protocols, all ports, anywhere -- standard open egress
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

  # Nodes talk to each other (pod to pod) -- all protocols,
  # all ports, self-referencing only
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Control plane to nodes -- full ephemeral range (1025-65535)
  # AWS recommends this range, not just kubelet's 10250, since
  # webhooks and extension API servers can register on other
  # ports too. Source is the cluster SG itself, properly scoped.
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # ALB to pods (app port) -- VPC-wide CIDR, not scoped to just
  # the ALB specifically (known gap, not yet tightened)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus scraping Node Exporter -- VPC-wide CIDR, not
  # scoped to just the monitoring node (known gap, not yet
  # tightened)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All protocols, all ports, anywhere -- standard open egress
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
# MANAGED APP NODE GROUP
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

  ############################################################
  # TAGS
  # k8s.io/cluster-autoscaler/* tags let autoDiscovery find
  # this ASG -- without them CA has nothing to scan
  ############################################################
  tags = {
    Name                                           = "${var.cluster_name}-node-group"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }
}

############################################################
# LAUNCH TEMPLATE FOR NODE GROUP
# Enforces IMDSv2 on worker nodes
# Attaches node group SG alongside EKS cluster primary SG
# Mirrors security standard from existing EC2 setup
############################################################

resource "aws_launch_template" "node_group" {
  name = "${var.cluster_name}-node-lt"

  metadata_options {
    http_tokens = "required"
  }

  ############################################################
  # Explicitly attach both SGs:
  # 1. node_group SG  - custom rules (ALB, Prometheus, pod-to-pod)
  # 2. EKS cluster primary SG - auto-created by EKS for cluster
  #    comms; specifying vpc_security_group_ids in a launch
  #    template overrides EKS auto-attachment, so we must
  #    include it manually
  ############################################################
  vpc_security_group_ids = [
    aws_security_group.node_group.id,
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  ]

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

############################################################
# MONITORING NODE GROUP
# Dedicated node for Prometheus, Alertmanager, Grafana
# Taint prevents app pods from landing here
############################################################

resource "aws_eks_node_group" "monitoring" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-monitoring-node-group"
  node_role_arn   = var.eks_node_group_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  scaling_config {
    min_size     = 1
    max_size     = 1
    desired_size = 1
  }

  ############################################################
  # LABEL
  # Matches the taint key/value so nodeAffinity rules (kube-
  # prometheus-stack, cluster-autoscaler) can actually select
  # or exclude this node -- taints and labels are independent,
  # EKS doesn't derive one from the other
  ############################################################
  labels = {
    dedicated = "monitoring"
  }

  taint {
    key    = "dedicated"
    value  = "monitoring"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.cluster_name}-monitoring-node-group"
  }
}

############################################################
# EBS CSI DRIVER ADDON
# Enables dynamic EBS volume provisioning for pods requesting
# PersistentVolumeClaims -- without it, stateful workloads
# like Prometheus lose all data on pod restart
############################################################
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.31.0-eksbuild.1"
  service_account_role_arn = var.ebs_csi_role_arn
}