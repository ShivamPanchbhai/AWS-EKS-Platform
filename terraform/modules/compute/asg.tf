########################################################
# AUTO SCALING GROUP
# Manages EC2 lifecycle for immutable deployments
########################################################

resource "aws_autoscaling_group" "this" {
  # Name derived from service name for reusability
  name = "${var.service_name}-asg"

  ######################################################
  # High Availability Configuration
  ######################################################

  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  # Subnets passed from root (do NOT assume default VPC)
  vpc_zone_identifier = var.subnet_ids
  # If var.subnet_ids contains subnets from different Availability Zones Then ASG will automatically distribute instances across those AZs.

  ######################################################
  # Attach ALB Target Group
  ######################################################

  # Target group ARN passed from ALB module
  target_group_arns = [var.target_group_arn]

  ######################################################
  # Launch Template Configuration
  ######################################################

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  ######################################################
  # Health Check Integration
  # ELB type enables ALB health check feedback
  ######################################################

  health_check_type         = "ELB"
  health_check_grace_period = 60

  ######################################################
  # Rolling Instance Refresh
  # Triggered when launch template changes
  ######################################################

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }

    # Ensures immutable rollout on LT version change
    triggers = ["launch_template"]
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
