########################################################
# ROUTE53 HOSTED ZONE LOOKUP
########################################################

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

############################################
# Request ACM Certificate
# Domain name dynamically derived from hosted zone
############################################

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    # Prevent downtime during certificate replacement
    create_before_destroy = true
  }

  tags = {
    Name = "Primary HTTPS Certificate"
  }
}

############################################
# Create CNAME record for DNS validation 
############################################

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
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
