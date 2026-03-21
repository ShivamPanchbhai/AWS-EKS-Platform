#############################
# IAM module: EC2 runtime role
#############################

# EC2 runtime role (assumed by EC2 instances)
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

# Instance profile (ASG/Launch Template attaches this to EC2)
resource "aws_iam_instance_profile" "ec2_runtime" {
  name = "ec2-runtime-instance-profile"
  role = aws_iam_role.ec2_runtime.name
}

#############################
# Attach AWS managed policies
#############################

# Allow EC2 to pull images from ECR (read-only)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allow EC2 to connect via SSM (no SSH required)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
