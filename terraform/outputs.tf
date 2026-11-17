output "order_queue_url" {
  description = "URL of the main order queue. Export this as QUEUE_URL before running the producer scripts."
  value       = aws_sqs_queue.orders.url
}

output "order_queue_arn" {
  description = "ARN of the main order queue."
  value       = aws_sqs_queue.orders.arn
}

output "order_dlq_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.order_dlq.url
}

output "order_dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = aws_sqs_queue.order_dlq.arn
}

output "order_notifications_topic_arn" {
  description = "ARN of the SNS topic that receives accepted-order notifications."
  value       = aws_sns_topic.order_notifications.arn
}

output "order_processor_function_name" {
  description = "Name of the order processor Lambda function."
  value       = aws_lambda_function.order_processor.function_name
}

output "order_processor_log_group" {
  description = "CloudWatch log group for the order processor."
  value       = aws_cloudwatch_log_group.order_processor.name
}
