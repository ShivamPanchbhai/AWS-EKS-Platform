##############################
# ROUTE53 HOSTED ZONE LOOKUP
##############################

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

############################################
# Request ACM Certificate
# This certificate is managed by Terraform
############################################

resource "aws_acm_certificate" "this" {

  # Primary domain for which HTTPS certificate is requested
  # IMPORTANT:
  # If this value changes, Terraform will create a NEW certificate.
  domain_name = var.domain_name

  # We are using DNS validation.
  # ACM will provide CNAME records which we must create in Route53.
  validation_method = "DNS"

  lifecycle {

    # Prevent HTTPS downtime during certificate replacement.
    #
    # What this does:
    # 1. Creates the NEW certificate first
    # 2. Waits for DNS validation to complete
    # 3. Only then destroys the OLD certificate
    #
    # Without this, Terraform would delete old certificate first,
    # which could break HTTPS temporarily.
    create_before_destroy = true
  }

  tags = {
    Name = "Primary HTTPS Certificate"
  }
}

######################################################################
# Create DNS records required for ACM certificate validation
######################################################################

resource "aws_route53_record" "acm_validation" {

  # ACM provides domain validation options after requesting a certificate.
  # Each domain (or subdomain) needs a special DNS record to prove ownership.
  # This loop creates those DNS records automatically.

  for_each = {
    # Loop through each domain validation option returned by ACM
    for dvo in aws_acm_certificate.this.domain_validation_options :

    # Use domain name as the key
    dvo.domain_name => {

      # These values are provided by ACM
      # We must create exactly this record in Route53
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  # Route53 hosted zone where the domain exists
  zone_id = data.aws_route53_zone.this.zone_id

  # DNS record name given by ACM (usually a long random string)
  name = each.value.name

  # Record type (usually CNAME for validation)
  type = each.value.type

  # DNS TTL (how long DNS caches the record)
  ttl = 60

  # The actual record value ACM expects
  records = [each.value.record]
}

############################################
# Wait until ACM certificate is validated
# Ensures ALB only receives valid certificate ARN
############################################

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for r in aws_route53_record.acm_validation : r.fqdn
  ]
}
