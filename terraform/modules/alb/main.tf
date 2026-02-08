############################################
# Application Load Balancer
############################################
resource "aws_lb" "this" {
  name               = "${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids

  enable_deletion_protection = false
}

############################################
# Target Group for EC2 (FastAPI via nginx)
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
        # ALB Listener (HTTP)
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
# ALB Listener (HTTPS)
############################################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}


