# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_lb_target_group" "alb" {
  name = "ALB"
}

resource "aws_autoscaling_group" "docker_asg" {
  name = "EC2-ASG"

  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  vpc_zone_identifier = data.aws_subnets.default.ids

 target_group_arns = [
    data.aws_lb_target_group.alb.arn
  ]

  launch_template {
    id      = aws_launch_template.docker_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 60

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }

    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "EC2-ASG"
    propagate_at_launch = true
  }
}
