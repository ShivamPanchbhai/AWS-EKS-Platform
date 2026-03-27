############################################
# Security Group for Monitoring Instance
############################################
resource "aws_security_group" "monitoring_sg" {

  name_prefix = "monitoring-sg"
  vpc_id      = var.vpc_id

  ############################################
  # Prometheus UI (9090)
  ############################################
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ############################################
  # Grafana UI (3000)
  ############################################
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ############################################
  # Outbound (required for scraping + installs)
  ############################################
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Monitoring EC2 Instance
############################################
resource "aws_instance" "monitoring" {

  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [
    aws_security_group.monitoring_sg.id
  ]

  iam_instance_profile = var.prometheus_instance_profile_name
  user_data_replace_on_change = true  # any update in user_data recreates the monitoring instance 

  ############################################
  # User Data
  ############################################
  user_data = <<-EOF
#!/bin/bash
set -e

############################################
# Base setup
############################################
dnf update -y
dnf install -y wget

############################################
# Install Prometheus
############################################
cd /tmp

wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz

tar -xvf prometheus-2.51.2.linux-amd64.tar.gz

mv prometheus-2.51.2.linux-amd64 /opt/prometheus

chmod +x /opt/prometheus/prometheus

############################################
# Prometheus config
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
nohup /opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.listen-address=":9090" > /var/log/prometheus.log 2>&1 &

############################################
# Install Grafana
############################################
cat > /etc/yum.repos.d/grafana.repo <<EOG
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOG

dnf clean all
dnf makecache

dnf install -y grafana

############################################
# Start Grafana
############################################
systemctl enable grafana-server
systemctl start grafana-server

EOF

  ############################################
  # Tags
  ############################################
  tags = {
    Name = "monitoring-instance"
  }
}
