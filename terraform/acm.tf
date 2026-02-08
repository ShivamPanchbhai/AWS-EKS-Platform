############################################
# ACM Certificate (DNS validated)
############################################

resource "aws_acm_certificate" "this" {
  domain_name       = "shivam.store"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# Route53 hosted zone lookup
############################################

data "aws_route53_zone" "this" {
  name         = "shivam.store"
  private_zone = false
}

############################################
# DNS records for ACM validation
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
# Wait for certificate validation
############################################

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for r in aws_route53_record.acm_validation : r.fqdn
  ]
}
