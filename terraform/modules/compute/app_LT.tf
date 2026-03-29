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

# Allow Node Exporter access from inside VPC
# → Monitoring EC2 (Prometheus) runs inside same VPC
# → It scrapes metrics on port 9100
# → No dependency on monitoring SG (decoupled design)
ingress {
  from_port   = 9100
  to_port     = 9100
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]
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

  name_prefix = "${var.service_name}-runtime-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  image_id      = var.ami_id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  ############################################
  # Enforce IMDSv2
  # AWS does this:

  # • Reject ALL metadata calls without token
  # • Allow ONLY token-based (IMDSv2) calls

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
set -x

############################################
# OS Update + Base Packages
############################################
dnf update -y
dnf install -y docker amazon-ssm-agent awscli

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
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz

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
# Authenticate to ECR (with retry)
############################################
for i in {1..5}; do
  aws ecr get-login-password --region ${var.region} \
    | docker login --username AWS --password-stdin $(echo ${var.repository_url} | cut -d'/' -f1) && break
  echo "ECR login failed, retrying..."
  sleep 5
done

############################################
# Pull Latest Image (with retry)
############################################
for i in {1..5}; do
  docker pull ${var.repository_url}:${var.image_tag} && break
  echo "Docker pull failed, retrying..."
  sleep 5
done

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

echo "Verifying container is running..."

for i in {1..10}; do
  docker ps | grep ${var.service_name} && break
  echo "Container not running yet, retrying..."
  sleep 5
done

if ! docker ps | grep ${var.service_name}; then
  echo "Container failed, restarting..."

  docker restart ${var.service_name}

  sleep 5

  if ! docker ps | grep ${var.service_name}; then
    echo "Container STILL not running"
  fi
fi
############################################
# WAIT FOR APP TO BE READY
############################################
echo "Waiting for app to be ready..."

for i in {1..60}; do
  STATUS=$(curl -s -o /dev/null -w '%%{http_code}' http://localhost:8000/health || echo 000)

  if [ "$STATUS" = "200" ]; then
    echo "App is ready"
    break
  fi

 if [ "$i" -eq 60 ]; then
  echo "App failed to start, but keeping instance alive"
 fi

  sleep 5
done

############################################
# FINAL STABILITY CHECK (STRICT)
############################################
echo "Ensuring app stability..."

SUCCESS_COUNT=0

while [ $SUCCESS_COUNT -lt 5 ]; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/health || echo 000)

  if [ "$STATUS" = "200" ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    echo "Success $SUCCESS_COUNT/5"
  else
    SUCCESS_COUNT=0
    echo "Failed check, resetting..."
  fi

  sleep 3
done

echo "App fully stable"


EOF
  )

############################################
# Tags for EC2 instances + volumes
# This is the IMPORTANT one
# Prometheus will look for this tag to discover instances
# Instead of hardcoding IPs, it will say:
# "Give me all EC2 where Monitoring = node-exporter"
############################################
tag_specifications {
  resource_type = "instance"

  tags = {
    # Just a human-readable name (you see this in AWS console)
    Name = "${var.service_name}-runtime" 
    Monitoring = "node-exporter"
  }
}

tag_specifications {
  resource_type = "volume"

  tags = {
    Name       = "${var.service_name}-runtime-volume"
    Monitoring = "node-exporter"
  }
}

} # aws_launch_template" "docker_lt ends here
