# Gmail SMTP app password for Alertmanager, stored in SSM by the bootstrap layer
variable "smtp_password" {
  description = "Gmail SMTP app password for Alertmanager"
  type        = string
  sensitive   = true
}

# Grafana admin password, stored in SSM by the bootstrap layer,
# fetched by ESO and mounted into Grafana via an existingSecret
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}