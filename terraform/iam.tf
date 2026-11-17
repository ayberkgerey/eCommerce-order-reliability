data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "order_processor" {
  name               = "${local.name_prefix}-order-processor"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "order_processor" {
  statement {
    sid    = "ConsumeOrderQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.orders.arn]
  }

  statement {
    sid       = "PublishOrderNotification"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.order_notifications.arn]
  }

  statement {
    sid    = "WriteOrderProcessorLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.order_processor.arn}:*"]
  }
}

resource "aws_iam_role_policy" "order_processor" {
  name   = "${local.name_prefix}-order-processor"
  role   = aws_iam_role.order_processor.id
  policy = data.aws_iam_policy_document.order_processor.json
}
