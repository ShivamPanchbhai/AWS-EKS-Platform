############################################
# Security Group for ALB
# Allows public HTTP and HTTPS traffic
############################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.service_name}-alb-sg"
  description = "Allow HTTP and HTTPS to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
# Application Load Balancer
# Public, multi-AZ, internet-facing
############################################

resource "aws_lb" "this" {
  name               = "${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups = [aws_security_group.alb_sg.id]

  enable_deletion_protection = false
}

############################################
# Target Group 
# Traffic forwarded to EC2 instances (nginx → FastAPI)
############################################

resource "aws_lb_target_group" "this" {
  name     = "${var.service_name}-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id  = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

############################################
# HTTP Listener
# Redirects all HTTP traffic to HTTPS
############################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
  type = "redirect"

  redirect {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}
}

############################################
# HTTPS LISTENER
# Uses ACM certificate output from ACM module
############################################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn # This comes from acm output file

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

########################################################
# ROUTE53 HOSTED ZONE LOOKUP
########################################################

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

########################################################
# PUBLIC A RECORD (ALIAS → ALB)
# Maps domain to the created ALB
########################################################

resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name   # Selects created ALB
    zone_id                = aws_lb.this.zone_id   # Required for alias
    evaluate_target_health = true
  }
}
