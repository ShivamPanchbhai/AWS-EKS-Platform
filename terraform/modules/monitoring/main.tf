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

# Alertmanager UI

ingress {
from_port   = 9093
to_port     = 9093
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

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

root_block_device {
    volume_size = 32 
    volume_type = "gp3"
  }

vpc_security_group_ids = [
aws_security_group.monitoring_sg.id
]

iam_instance_profile        = var.prometheus_instance_profile_name
user_data_replace_on_change = true

user_data = <<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>/var/log/user-data-error.log
set -x

############################################
# SSM (dont touch this or SSM will not work)
############################################
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

############################################
# Base setup
############################################
dnf install -y java-17-amazon-corretto wget || true

mkdir -p /var/log
mkdir -p /opt/prometheus/data
mkdir -p /opt/alertmanager/data

echo "=== STARTING USER DATA ==="

############################################
# Install Prometheus
############################################
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz
tar -xzf prometheus-2.51.2.linux-amd64.tar.gz

mkdir -p /opt/prometheus
mv prometheus-2.51.2.linux-amd64 /opt/prometheus

chmod +x /opt/prometheus/prometheus-2.51.2.linux-amd64/prometheus

############################################
# Prometheus config
############################################

cat <<-EOT > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["localhost:9093"]

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
        
  - job_name: 'cloudwatch'
    honor_labels: true
    honor_timestamps: false
    static_configs:
     - targets: ['localhost:9106']

EOT

############################################
# Alert rules
############################################
cat <<-EOF_RULE > /opt/prometheus/alert.rules.yml
groups:
  - name: test-alerts
    rules:
      - alert: ASGAtMaxCapacity
        expr: aws_autoscaling_group_desired_capacity_average == on (auto_scaling_group_name) aws_autoscaling_group_max_size_average
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "ASG reached max capacity"
EOF_RULE

############################################
# Install Grafana
############################################
cd /tmp
wget -q https://dl.grafana.com/oss/release/grafana-10.4.2-1.x86_64.rpm
dnf install -y ./grafana-10.4.2-1.x86_64.rpm

############################################
# Install Alertmanager
############################################
cd /opt
wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xzf alertmanager-0.27.0.linux-amd64.tar.gz

mkdir -p /opt/alertmanager
mv alertmanager-0.27.0.linux-amd64/alertmanager /opt/alertmanager/
mv alertmanager-0.27.0.linux-amd64/amtool /opt/alertmanager/

chmod +x /opt/alertmanager/alertmanager

# Fetch SMTP password from SSM
SMTP_PASSWORD=$(aws ssm get-parameter \
  --name "/monitoring/smtp-password" \
  --with-decryption \
  --region ap-south-1 \
  --query 'Parameter.Value' \
  --output text)

############################################
# This ensures workflow fails if passowrd field is empty
# otherwise alertmanager will not trigger
############################################

if [ -z "$SMTP_PASSWORD" ]; then
  echo "ERROR: SMTP password is empty, SSM fetch failed. Exiting."
  exit 1
fi

############################################
# Writing alertmanager config
############################################

cat <<-EOF_ALERT > /opt/alertmanager/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'panchbhaishivam@gmail.com'
  smtp_auth_username: 'panchbhaishivam@gmail.com'
  smtp_auth_password: '$SMTP_PASSWORD'
  smtp_require_tls: true

route:
  receiver: "email-alert"

receivers:
  - name: "email-alert"
    email_configs:
      - to: "panchbhaishivam@gmail.com"
        send_resolved: true
EOF_ALERT

############################################
# Install CloudWatch Exporter
############################################
cd /opt
wget -q https://github.com/prometheus/cloudwatch_exporter/releases/download/v0.15.0/cloudwatch_exporter-0.15.0-jar-with-dependencies.jar

mkdir -p /opt/cloudwatch_exporter
mv cloudwatch_exporter-0.15.0-jar-with-dependencies.jar /opt/cloudwatch_exporter/cloudwatch_exporter.jar

cat <<-EOF_CW > /opt/cloudwatch_exporter/config.yml
region: ap-south-1

metrics:
  - aws_namespace: AWS/AutoScaling
    aws_metric_name: GroupDesiredCapacity
    aws_dimensions: [AutoScalingGroupName]
    aws_dimension_select:
      AutoScalingGroupName: ["ehr-asg"]
    aws_statistics: [Average]

  - aws_namespace: AWS/AutoScaling
    aws_metric_name: GroupMaxSize
    aws_dimensions: [AutoScalingGroupName]
    aws_dimension_select:
      AutoScalingGroupName: ["ehr-asg"]
    aws_statistics: [Average]

  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_statistics: [Average]
EOF_CW

############################################
# START SERVICES (NO SYSTEMD)
############################################

set +m

echo "=== STARTING PROMETHEUS ==="
nohup /opt/prometheus/prometheus-2.51.2.linux-amd64/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  > /var/log/prometheus.log 2>&1 &
disown

echo "=== STARTING ALERTMANAGER ==="
nohup /opt/alertmanager/alertmanager \
  --config.file=/opt/alertmanager/alertmanager.yml \
  --storage.path=/opt/alertmanager/data \
  > /var/log/alertmanager.log 2>&1 &
disown

echo "=== STARTING GRAFANA ==="
nohup /usr/sbin/grafana-server \
  --homepath /usr/share/grafana \
  > /var/log/grafana.log 2>&1 &
disown

echo "=== STARTING CLOUDWATCH EXPORTER ==="
nohup /usr/bin/java -jar /opt/cloudwatch_exporter/cloudwatch_exporter.jar \
  9106 /opt/cloudwatch_exporter/config.yml \
  > /var/log/cloudwatch_exporter.log 2>&1 &
disown

############################################
# AUTO START ON REBOOT (CRON)
############################################

(crontab -l 2>/dev/null; echo "@reboot nohup /opt/prometheus/prometheus-2.51.2.linux-amd64/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data > /var/log/prometheus.log 2>&1 &") | crontab -

(crontab -l 2>/dev/null; echo "@reboot nohup /opt/alertmanager/alertmanager --config.file=/opt/alertmanager/alertmanager.yml --storage.path=/opt/alertmanager/data > /var/log/alertmanager.log 2>&1 &") | crontab -

(crontab -l 2>/dev/null; echo "@reboot nohup /usr/sbin/grafana-server --homepath /usr/share/grafana > /var/log/grafana.log 2>&1 &") | crontab -

(crontab -l 2>/dev/null; echo "@reboot nohup /usr/bin/java -jar /opt/cloudwatch_exporter/cloudwatch_exporter.jar 9106 /opt/cloudwatch_exporter/config.yml > /var/log/cloudwatch_exporter.log 2>&1 &") | crontab -

echo "=== USER DATA COMPLETE ==="

EOF

tags = {
Name = "monitoring-instance"
}
}
