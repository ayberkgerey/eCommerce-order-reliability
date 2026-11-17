variable "aws_region" {
  description = "AWS region for every resource in this project."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must look like a region name, for example eu-central-1."
  }
}

variable "project_name" {
  description = "Short prefix used in resource names."
  type        = string
  default     = "ecommerce-order"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3-32 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment label used in resource names."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,16}$", var.environment))
    error_message = "environment must be 2-16 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lambda_memory_mb" {
  description = "Memory allocated to the order processor, in MB."
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_mb == floor(var.lambda_memory_mb) && var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 512
    error_message = "lambda_memory_mb must be a whole number from 128 to 512 so this lab remains inexpensive."
  }
}

variable "lambda_timeout_seconds" {
  description = "Order processor timeout, in seconds. The SQS visibility timeout must be at least six times this value."
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_timeout_seconds == floor(var.lambda_timeout_seconds) && var.lambda_timeout_seconds >= 3 && var.lambda_timeout_seconds <= 30
    error_message = "lambda_timeout_seconds must be a whole number from 3 to 30."
  }
}

variable "sqs_visibility_timeout_seconds" {
  description = "How long a received order stays hidden from other consumers. Must be at least six times the Lambda timeout."
  type        = number
  default     = 60

  validation {
    condition     = var.sqs_visibility_timeout_seconds == floor(var.sqs_visibility_timeout_seconds) && var.sqs_visibility_timeout_seconds >= 18 && var.sqs_visibility_timeout_seconds <= 180
    error_message = "sqs_visibility_timeout_seconds must be a whole number from 18 to 180."
  }
}

variable "sqs_message_retention_seconds" {
  description = "How long the main queue keeps an order message."
  type        = number
  default     = 345600

  validation {
    condition     = var.sqs_message_retention_seconds == floor(var.sqs_message_retention_seconds) && var.sqs_message_retention_seconds >= 60 && var.sqs_message_retention_seconds <= 1209600
    error_message = "sqs_message_retention_seconds must be a whole number of seconds, from 60 to 14 days."
  }
}

variable "dlq_message_retention_seconds" {
  description = "How long the dead-letter queue keeps a failed order so an operator can inspect it."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds == floor(var.dlq_message_retention_seconds) && var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be a whole number of seconds, from 60 to 14 days."
  }
}

variable "sqs_max_receive_count" {
  description = "Receives allowed before SQS moves a message to the dead-letter queue."
  type        = number
  default     = 3

  validation {
    condition     = var.sqs_max_receive_count == floor(var.sqs_max_receive_count) && var.sqs_max_receive_count >= 1 && var.sqs_max_receive_count <= 5
    error_message = "sqs_max_receive_count must be a whole number from 1 to 5."
  }
}

variable "lambda_batch_size" {
  description = "Maximum number of orders Lambda receives in one batch."
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_batch_size == floor(var.lambda_batch_size) && var.lambda_batch_size >= 1 && var.lambda_batch_size <= 10
    error_message = "lambda_batch_size must be a whole number from 1 to 10."
  }
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps order processor logs."
  type        = number
  default     = 14

  validation {
    condition     = contains([7, 14, 30], var.log_retention_days)
    error_message = "log_retention_days must be 7, 14, or 30."
  }
}

variable "sns_email_endpoint" {
  description = "Optional email address subscribed to accepted-order notifications. Leave empty to create no subscription."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.sns_email_endpoint == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sns_email_endpoint))
    error_message = "sns_email_endpoint must be empty or one email address."
  }
}
