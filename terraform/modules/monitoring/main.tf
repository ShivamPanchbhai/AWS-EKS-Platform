############################################
# Security Group for Monitoring Instance
############################################
resource "aws_security_group" "monitoring_sg" {
  name   = "monitoring-sg"
  vpc_id = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # later restrict to your IP
  }

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana UI (we’ll use later)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound (needed to scrape 9100)
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
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  ############################################
  # User Data (Prometheus install)
  ############################################
  user_data = <<-EOF
#!/bin/bash
set -e

dnf update -y
dnf install -y wget

cd /opt
wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-2.51.2.linux-amd64.tar.gz
tar -xvf prometheus-2.51.2.linux-amd64.tar.gz
mv prometheus-2.51.2.linux-amd64 prometheus

cat <<EOT > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['${var.app_instance_private_ip}:9100']
EOT

/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.listen-address=":9090" &
EOF

  tags = {
    Name = "monitoring-instance"
  }
}
