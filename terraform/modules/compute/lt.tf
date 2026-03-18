############################################
# EC2 Security Group
# Only ALB can talk to EC2 on port 8000
# Prometheus can scrape Node Exporter on 9100
############################################
resource "aws_security_group" "ec2_sg" {
  name   = "${var.service_name}-ec2-sg"
  vpc_id = var.vpc_id

  # ALB → App
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Prometheus → Node Exporter
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [var.prometheus_sg_id]
  }

  # Outbound internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Launch Template (Docker Runtime + Observability)
############################################
resource "aws_launch_template" "docker_lt" {

  name_prefix = "${var.service_name}-runtime-"

  image_id      = var.ami_id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  ############################################
  # Enforce IMDSv2
  ############################################
  metadata_options {
    http_tokens = "required"
  }

  ############################################
  # IAM Instance Profile
  ############################################
  iam_instance_profile {
    name = var.instance_profile_name
  }

  ############################################
  # Root Volume
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
  # User Data
  ############################################
  user_data = base64encode(<<-EOF
#!/bin/bash
set -e

############################################
# OS Update + Base Packages
############################################
dnf update -y
dnf install -y docker amazon-ssm-agent awscli curl

############################################
# Enable Services
############################################
systemctl enable docker
systemctl start docker

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

############################################
# Wait for Docker
############################################
until docker info >/dev/null 2>&1; do
  sleep 2
done

############################################
# Install Node Exporter
############################################

useradd --no-create-home --shell /bin/false node_exporter

cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-1.8.1.linux-amd64.tar.gz

tar xvf node_exporter-1.8.1.linux-amd64.tar.gz
cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat <<EOT > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOT

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

############################################
# Authenticate to ECR
############################################
aws ecr get-login-password --region ${var.region} \
  | docker login --username AWS --password-stdin ${var.repository_url}

############################################
# Pull Latest Image
############################################
docker pull ${var.repository_url}:${var.image_tag}

############################################
# Remove Old Container
############################################
docker rm -f ${var.service_name} || true

############################################
# Run Application Container
############################################
docker run -d \
  --name ${var.service_name} \
  --restart unless-stopped \
  -p 8000:8000 \
  ${var.repository_url}:${var.image_tag}

EOF
  )

  ############################################
  # Tags
  ############################################
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.service_name}-runtime"
    }
  }
}
