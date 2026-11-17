data "archive_file" "order_processor" {
  type        = "zip"
  source_file = "${path.module}/../src/order-processor/index.js"
  output_path = "${path.module}/build/order-processor.zip"
}

resource "aws_lambda_function" "order_processor" {
  function_name    = "${local.name_prefix}-order-processor"
  description      = "Validates queued orders and publishes an accepted-order notification."
  role             = aws_iam_role.order_processor.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.order_processor.output_path
  source_code_hash = data.archive_file.order_processor.output_base64sha256
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_seconds

  environment {
    variables = {
      ORDER_TOPIC_ARN = aws_sns_topic.order_notifications.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.order_processor,
    aws_cloudwatch_log_group.order_processor,
  ]
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn        = aws_sqs_queue.orders.arn
  function_name           = aws_lambda_function.order_processor.arn
  batch_size              = var.lambda_batch_size
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true

  depends_on = [aws_iam_role_policy.order_processor]
}
