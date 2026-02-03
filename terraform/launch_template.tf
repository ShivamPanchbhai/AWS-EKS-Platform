resource "aws_launch_template" "docker_lt" {
  name_prefix   = "docker-runtime-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = "ec2-ssm-role"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

 user_data = base64encode(<<-EOF
#!/bin/bash
set -e

# Update and install required packages
dnf update -y
dnf install -y docker amazon-ssm-agent

# Start services
systemctl enable docker
systemctl start docker
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Wait for Docker daemon
until docker info >/dev/null 2>&1; do
  sleep 2
done

# Login to ECR (EC2 role is used automatically)
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin 306991549269.dkr.ecr.ap-south-1.amazonaws.com

# Pull latest app image
docker pull 306991549269.dkr.ecr.ap-south-1.amazonaws.com/ehr-service:latest

# Run container
docker rm -f ehr || true
docker run -d \
  --name ehr \
  -p 8000:8000 \
  306991549269.dkr.ecr.ap-south-1.amazonaws.com/ehr-service:latest
EOF
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "docker-runtime-asg"
    }
  }
}
