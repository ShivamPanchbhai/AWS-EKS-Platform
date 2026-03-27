############################################
# Security Group for Monitoring Instance
############################################
resource "aws_security_group" "monitoring_sg" {

  # Name of the security group (for identification in AWS console)
  name_prefix = "monitoring-sg"

  # Attach this security group to the same VPC as our app
  vpc_id = var.vpc_id

############################################
 # Allow access to Prometheus UI
############################################
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"

    # This lets us open Prometheus dashboard in browser
    cidr_blocks = ["0.0.0.0/0"]
  }

############################################
 # Allow access to Grafana UI
############################################
ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"

  # Grafana UI access
  cidr_blocks = ["0.0.0.0/0"]
}
############################################
 # Outbound traffic (very important)
############################################
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    # Allow this monitoring EC2 to talk to anything
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

  # attaching monitoring instance profile to monitoring EC2 IAM Role
  iam_instance_profile = var.prometheus_instance_profile_name

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
wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz

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

scrape_configs:
  - job_name: 'node-exporter'

    ec2_sd_configs:
      - region: ap-south-1
        port: 9100

    relabel_configs:
      - source_labels: [__meta_ec2_tag_Monitoring]
        regex: node-exporter
        action: keep
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

############################################
# Install Grafana
############################################

cat <<EOF_GRAFANA > /etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
EOF_GRAFANA

dnf install -y grafana
############################################
# Start Grafana
############################################

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

EOF
############################################
# Tags (for identification in AWS)
############################################
  tags = {
    # Just helps us identify this instance in console
    Name = "monitoring-instance"
  }

} # "aws_instance" "monitoring" block ends here
