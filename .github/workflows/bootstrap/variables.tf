variable "smtp_password" {
  description = "Gmail SMTP app password for Alertmanager"
  type        = string
  sensitive   = true
}