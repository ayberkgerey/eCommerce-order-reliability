resource "aws_sns_topic" "order_notifications" {
  name = "${local.name_prefix}-order-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.sns_email_endpoint == "" ? 0 : 1

  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}
