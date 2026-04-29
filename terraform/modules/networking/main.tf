############################################################
# VPC
############################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.service_name}-vpc"
  }
}

############################################################
# INTERNET GATEWAY
# Required for public subnets to reach internet
############################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.service_name}-igw"
  }
}

############################################################
# PUBLIC SUBNETS
# ALB lives here
# One per AZ for high availability
############################################################

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.service_name}-public-${var.availability_zones[count.index]}"
    # Required for AWS Load Balancer Controller to discover public subnets
    "kubernetes.io/role/elb" = "1"
  }
}

############################################################
# PRIVATE SUBNETS
# EKS worker nodes live here
# No direct internet access, outbound via NAT gateway
############################################################

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "${var.service_name}-private-${var.availability_zones[count.index]}"
    # Required for AWS Load Balancer Controller to discover private subnets
    "kubernetes.io/role/internal-elb" = "1"
    # Required for EKS to know which subnets belong to the cluster
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

############################################################
# ELASTIC IP FOR NAT GATEWAY
############################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.service_name}-nat-eip"
  }
}

############################################################
# NAT GATEWAY
# Sits in public subnet
# Allows private subnet nodes to reach internet (ECR, SSM etc.)
# One NAT gateway is enough for a portfolio project
############################################################

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.service_name}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

############################################################
# PUBLIC ROUTE TABLE
# Routes internet traffic via Internet Gateway
############################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.service_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

############################################################
# PRIVATE ROUTE TABLE
# Routes outbound traffic via NAT Gateway
############################################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.service_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}