resource "aws_security_group" "ec2_sg" {
  name   = "${var.service_name}-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for EC2 instances that will run Docker containers
resource "aws_launch_template" "docker_lt" {

vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Prefix for launch template name (AWS adds random suffix)
  name_prefix = "docker-runtime-"

  # Base AMI used for instances (Amazon Linux)
  image_id = var.ami_id

  # EC2 instance size
  instance_type = "t3.micro"

  # IAM role attached to EC2
  # Used for ECR pull + SSM access
  iam_instance_profile {
    name = "ec2-ssm-role"
  }

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      # Disk size in GB
      volume_size = 30

      # gp3 = modern EBS volume type
      volume_type = "gp3"

      # Delete disk when instance is terminated
      delete_on_termination = true
    }
  }

  # User data runs on instance boot (cloud-init)
  # Base64 encoding is required by AWS
  user_data = base64encode(<<-EOF
#!/bin/bash
set -e

# Exit immediately if any command fails

# Update system packages and install required tools
dnf update -y
dnf install -y docker amazon-ssm-agent awscli

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Enable and start SSM agent (no SSH needed)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Wait until Docker daemon is fully ready
until docker info >/dev/null 2>&1; do
  sleep 2
done

# Authenticate to ECR
# Uses EC2 IAM role automatically (no credentials stored)
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin 306991549269.dkr.ecr.ap-south-1.amazonaws.com

# Pull the Docker image tagged with commit SHA
# image_tag is passed from CI/CD
docker pull 306991549269.dkr.ecr.ap-south-1.amazonaws.com/ehr-service:${var.image_tag}

# Remove old container if it exists (safe cleanup)
docker rm -f ehr || true

# Run the application container
docker run -d \
  --name ehr \
  -p 8000:8000 \
  306991549269.dkr.ecr.ap-south-1.amazonaws.com/ehr-service:${var.image_tag}
EOF
  )

  # Tags applied to EC2 instances created from this template
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "docker-runtime-asg"
    }
  }
}
