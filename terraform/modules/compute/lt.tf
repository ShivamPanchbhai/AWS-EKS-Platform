############################################
# EC2 Security Group
# Only ALB can talk to EC2 on port 8000
############################################
resource "aws_security_group" "ec2_sg" {
  name   = "${var.service_name}-ec2-sg"
  vpc_id = var.vpc_id

  # Allow traffic ONLY from ALB Security Group
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Allow outbound internet access (for ECR pull, updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Launch Template (Docker Runtime Instance)
############################################
resource "aws_launch_template" "docker_lt" {

  name_prefix = "${var.service_name}-runtime-"

  image_id      = var.ami_id
  instance_type = "t3.micro"

  # Attach EC2 Security Group
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  ############################################
  # Enforce IMDSv2 (Prevents credential theft)
  ############################################
  metadata_options {
    http_tokens = "required"
  }

  ############################################
  # Attach IAM Instance Profile
  # Used for:
  # - ECR pull
  # - SSM access
  ############################################
  iam_instance_profile {
    name = var.instance_profile_name
  }

  ############################################
  # Root Volume Configuration
  ############################################
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  ############################################
  # User Data Script
  # Runs at instance boot
  ############################################
  user_data = base64encode(<<-EOF
#!/bin/bash
set -e

# Update OS
dnf update -y

# Install Docker + SSM + AWS CLI
dnf install -y docker amazon-ssm-agent awscli

# Enable services
systemctl enable docker
systemctl start docker

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Wait for Docker daemon to be ready
until docker info >/dev/null 2>&1; do
  sleep 2
done

############################################
# Authenticate to ECR
# Uses EC2 IAM Role (No credentials stored)
############################################
aws ecr get-login-password --region ${var.region} \
  | docker login --username AWS --password-stdin ${var.repository_url}

############################################
# Pull Docker Image (Commit SHA Tag)
############################################
docker pull ${var.repository_url}:${var.image_tag}

############################################
# Remove Old Container (Safe Cleanup)
############################################
docker rm -f ${var.service_name} || true

############################################
# Run Application Container
# --restart ensures container auto-recovers
############################################
docker run -d \
  --name ${var.service_name} \
  --restart unless-stopped \
  -p 8000:8000 \
  ${var.repository_url}:${var.image_tag}

EOF
  )

  ############################################
  # Tag EC2 Instances Created by ASG
  ############################################
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.service_name}-runtime"
    }
  }
}
