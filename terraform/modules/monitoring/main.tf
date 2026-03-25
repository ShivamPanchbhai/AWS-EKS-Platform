############################################
# Security Group for Monitoring Instance
############################################
resource "aws_security_group" "monitoring_sg" {

  # Name of the security group (just for identification in AWS console)
  name = "monitoring-sg"

  # Attach this security group to the same VPC as your app
  vpc_id = var.vpc_id

  ############################################
  # Allow SSH (for manual access if needed)
  ############################################
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # Allow from anywhere (not safe for production)
    # You kept this for debugging / initial setup
    cidr_blocks = ["0.0.0.0/0"]
  }

  ############################################
  # Allow access to Prometheus UI
  ############################################
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"

    # This lets you open Prometheus dashboard in browser
    cidr_blocks = ["0.0.0.0/0"]
  }

  ############################################
  # Outbound traffic (very important)
  ############################################
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    # Allow this EC2 to talk to anything
    # Needed so Prometheus can:
    # → reach app instances
    # → scrape metrics on port 9100
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Monitoring EC2 Instance
############################################
resource "aws_instance" "monitoring" {

  # OS image (Amazon Linux)
  ami = var.ami_id

  # Small instance is enough for Prometheus initially
  instance_type = "t3.micro"

  # Launch instance inside selected subnet
  subnet_id = var.subnet_id

  # Attach the security group we created above
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  ############################################
  # User Data (runs at instance startup)
  ############################################
  user_data = <<-EOF
#!/bin/bash
set -e

############################################
# Update OS and install basic tool
############################################
dnf update -y
dnf install -y wget

############################################
# Download Prometheus
############################################
cd /opt

# Fetch latest Prometheus binary
wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-2.51.2.linux-amd64.tar.gz

# Extract it
tar -xvf prometheus-2.51.2.linux-amd64.tar.gz

# Rename folder to simple name
mv prometheus-2.51.2.linux-amd64 prometheus

############################################
# Create basic Prometheus config
############################################
cat <<EOT > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

# Right now:
# No targets defined yet
# Later we will add EC2 auto-discovery here
EOT

############################################
# Start Prometheus
############################################

# Run Prometheus server:
# → reads config file
# → stores metrics locally
# → exposes UI on port 9090
/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.listen-address=":9090" &
EOF

  ############################################
  # Tags (for identification in AWS)
  ############################################
  tags = {
    # Just helps you identify this instance in console
    Name = "monitoring-instance"
  }
}
