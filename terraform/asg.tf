resource "aws_autoscaling_group" "docker_asg" {
  name = "docker-runtime-asg"

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  vpc_zone_identifier = [
    "subnet-076bfaf1ee40ec8fd"
  ]

  launch_template {
    id      = aws_launch_template.docker_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "docker-runtime-asg"
    propagate_at_launch = true
  }
}
