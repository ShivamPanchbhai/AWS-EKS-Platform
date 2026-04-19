#############################
# IAM module for app instance
#############################

# EC2 runtime role 
resource "aws_iam_role" "ec2_runtime" {
  name = "ec2-runtime-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Instance profile for app EC2
resource "aws_iam_instance_profile" "ec2_runtime" {
  name = "ec2-runtime-instance-profile"
  role = aws_iam_role.ec2_runtime.name
}

#############################
# Attach AWS managed policies (App EC2)
#############################

# ECR pull access
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM access (for Session Manager)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################
# IAM module for Monitoring instance
#############################

resource "aws_iam_role" "prometheus" {
  name = "prometheus-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "prometheus_cloudwatch" {
  name = "prometheus-cloudwatch-access"
  role = aws_iam_role.prometheus.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################
# Instance profile for monitoring EC2
#############################

resource "aws_iam_instance_profile" "prometheus" {
  name = "prometheus-instance-profile"
  role = aws_iam_role.prometheus.name
}

#############################
# Attach policies (Monitoring EC2)
#############################

# Required for EC2 auto-discovery
resource "aws_iam_role_policy" "prometheus_ec2_discovery" {
  name = "prometheus-ec2-discovery"
  role = aws_iam_role.prometheus.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Required for SSM (Session Manager)
resource "aws_iam_role_policy_attachment" "prometheus_ssm_core" {
  role       = aws_iam_role.prometheus.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
