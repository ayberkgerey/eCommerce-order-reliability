resource "aws_sqs_queue" "order_dlq" {
  name                       = "${local.name_prefix}-order-dlq"
  message_retention_seconds  = var.dlq_message_retention_seconds
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  sqs_managed_sse_enabled    = true
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name_prefix}-orders"
  message_retention_seconds  = var.sqs_message_retention_seconds
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  lifecycle {
    precondition {
      condition     = var.sqs_visibility_timeout_seconds >= var.lambda_timeout_seconds * 6
      error_message = "SQS visibility timeout must be at least six times the Lambda timeout."
    }
  }
}

# Kept separate from the queue resources so the source queue and the DLQ
# do not depend on each other's ARNs in a cycle.
resource "aws_sqs_queue_redrive_allow_policy" "order_dlq" {
  queue_url = aws_sqs_queue.order_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.orders.arn]
  })
}
