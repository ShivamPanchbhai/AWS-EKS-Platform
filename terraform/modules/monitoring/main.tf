############################################
# Security Group for Monitoring Instance
############################################
resource "aws_security_group" "monitoring_sg" {

  name_prefix = "monitoring-sg"
  vpc_id      = var.vpc_id

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # Alertmanager UI  # Without this: Alertmanager will run BUT we can't access UI

 ingress {
  from_port   = 9093
  to_port     = 9093
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
 
  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} # monitoring_sg block ends here

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

  iam_instance_profile         = var.prometheus_instance_profile_name
  user_data_replace_on_change  = true

############################################
# User Data
# -e → exit on error
# -x → print commands (debug)
############################################
  user_data = <<-EOF
#!/bin/bash
set -x

echo "=== STARTING USER DATA ==="

############################################
# Base setup
############################################
dnf update -y
dnf install -y wget

############################################
# Install Prometheus
############################################
echo "=== INSTALLING PROMETHEUS ==="

cd /tmp

wget -q https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz

tar -xzf prometheus-2.51.2.linux-amd64.tar.gz

mkdir -p /opt/prometheus

mv prometheus-2.51.2.linux-amd64/* /opt/prometheus/

cp /opt/prometheus/prometheus /usr/local/bin/
cp /opt/prometheus/promtool /usr/local/bin/

chmod +x /usr/local/bin/prometheus
chmod +x /usr/local/bin/promtool

############################################
# Prometheus config
############################################
echo "=== CONFIGURING PROMETHEUS ==="

cat <<EOT > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "localhost:9093"

rule_files:
  - /opt/prometheus/alert.rules.yml

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
# Prometheus alert rules
############################################
echo "=== CREATING ALERT RULES ==="

cat <<EOF_RULE > /opt/prometheus/alert.rules.yml
groups:
  - name: test-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance is down"
EOF_RULE

############################################
# Systemd service
############################################
echo "=== SETTING UP PROMETHEUS SERVICE ==="

cat <<EOP > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
ExecStart=/usr/local/bin/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data

Restart=always

[Install]
WantedBy=multi-user.target
EOP

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

############################################
# Install Grafana
############################################
echo "=== INSTALLING GRAFANA ==="

cd /tmp

wget -q https://dl.grafana.com/oss/release/grafana-10.4.2-1.x86_64.rpm

dnf install -y ./grafana-10.4.2-1.x86_64.rpm

############################################
# Start Grafana
############################################
echo "=== STARTING GRAFANA ==="

systemctl daemon-reload || true
systemctl enable grafana-server.service || true
systemctl start grafana-server.service || true


############################################
# Install Alertmanager
############################################
echo "=== INSTALLING ALERTMANAGER ==="

cd /opt

# -q gives clean logs

wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz

tar -xzf alertmanager-0.27.0.linux-amd64.tar.gz

mkdir -p /opt/alertmanager

mv alertmanager-0.27.0.linux-amd64/* /opt/alertmanager/

chmod +x /opt/alertmanager/alertmanager

mkdir -p /opt/alertmanager/data

############################################
# Create Alertmanager config
############################################
cat <<EOF_ALERT > /opt/alertmanager/alertmanager.yml
route:
  receiver: "default"

receivers:
  - name: "default"
EOF_ALERT

############################################
# Setup Alertmanager systemd service
############################################
echo "=== SETTING UP ALERTMANAGER SERVICE ==="

cat <<EOF_SERVICE > /etc/systemd/system/alertmanager.service

[Unit]
Description=Alertmanager
After=network.target

[Service]
User=root
ExecStart=/opt/alertmanager/alertmanager \
  --config.file=/opt/alertmanager/alertmanager.yml \
  --storage.path=/opt/alertmanager/data

Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE

############################################
# Start Alertmanager
############################################
echo "=== STARTING ALERTMANAGER ==="

systemctl daemon-reload || true
systemctl enable alertmanager.service || true
systemctl start alertmanager.service || true

echo "=== USER DATA COMPLETE ==="

EOF

############################################
 # Tags
############################################
  tags = {
    Name = "monitoring-instance"
  }
} # monitoring code block ends here
