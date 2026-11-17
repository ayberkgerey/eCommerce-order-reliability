# Lambda and SQS already publish the metrics this lab uses.
# No alarms or dashboards are created; inspect those metrics in the console.

resource "aws_cloudwatch_log_group" "order_processor" {
  name              = "/aws/lambda/${local.name_prefix}-order-processor"
  retention_in_days = var.log_retention_days
}
