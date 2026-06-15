############################################################
# CLOUDWATCH MODULE
# Creates an SNS topic for alerts and a CloudWatch Alarm
# that fires when the app node group ASG approaches max capacity
# Acts as an early warning so node_max_size can be raised
# before Cluster Autoscaler hits its ceiling
############################################################

############################################################
# SNS TOPIC
# Notification channel for capacity alerts
############################################################
resource "aws_sns_topic" "node_capacity_alerts" {
  name = "eks-node-capacity-alerts"
}

############################################################
# SNS SUBSCRIPTION
# Sends alarm notifications to your email
# AWS will send a confirmation link to this email -- must be
# clicked once before notifications start working
############################################################
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.node_capacity_alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

############################################################
# CLOUDWATCH ALARM: NODE GROUP NEAR MAX CAPACITY
# GroupInServiceInstances is the count of running instances
# in the ASG backing the EKS node group
# Threshold = 95% of max_size, rounded down
# e.g. max_size = 10 -> threshold = 9
############################################################
resource "aws_cloudwatch_metric_alarm" "asg_near_max_capacity" {
  alarm_name          = "eks-node-group-near-max-capacity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1

  metric_name = "GroupInServiceInstances"
  namespace   = "AWS/AutoScaling"
  period      = 300
  statistic   = "Average"

  # 95% of max_size, rounded down to nearest whole instance
  threshold = floor(var.max_size * 0.95)

  alarm_description = "Fires when the EKS app node group is close to its max size, signaling Cluster Autoscaler is near its ceiling"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  alarm_actions = [aws_sns_topic.node_capacity_alerts.arn]
  ok_actions    = [aws_sns_topic.node_capacity_alerts.arn]
}