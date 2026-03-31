########################################################
# AUTO SCALING GROUP
# Manages EC2 lifecycle for immutable deployments
########################################################

resource "aws_autoscaling_group" "this" {

  name = "${var.service_name}-asg"

  ######################################################
  # Capacity Configuration
  ######################################################

  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  default_instance_warmup = 30

  ######################################################
  # Multi-AZ Placement
  ######################################################

  vpc_zone_identifier = var.subnet_ids

  ######################################################
  # Attach ASG to ALB Target Group
  ######################################################

  target_group_arns = [var.target_group_arn]

  ######################################################
  # Launch Template Configuration
  ######################################################

  launch_template {
    id      = aws_launch_template.docker_lt.id
    version = "$Latest"
  }

  ######################################################
  # Health Check Integration
  ######################################################

  # Uses ALB health checks instead of EC2 status checks
  health_check_type         = "ELB"
  health_check_grace_period = 180

  ######################################################
  # Rolling Instance Refresh (Immutable Deployments)
  ######################################################

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  ######################################################
  # Resource Tagging
  ######################################################

  tag {
    key                 = "Name"
    value               = "${var.service_name}-ec2"
    propagate_at_launch = true
  }
}

########################################################
# TARGET TRACKING SCALING POLICY
# Automatically adjusts instance count based on CPU
########################################################

resource "aws_autoscaling_policy" "cpu_target_tracking" {

  name                   = "${var.service_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60.0

  }
}
