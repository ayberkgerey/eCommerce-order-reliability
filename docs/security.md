# Security

## Execution role

The order processor assumes `ecommerce-order-dev-order-processor`. No access key is stored in source, in Lambda environment variables, or in Terraform. The local producer scripts use the AWS SDK default credential chain and the profile you already configured for the AWS CLI.

The inline policy is three statements:

| Statement | Actions | Resource |
| --- | --- | --- |
| `ConsumeOrderQueue` | `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`, `sqs:ChangeMessageVisibility` | Order queue only |
| `PublishOrderNotification` | `sns:Publish` | Notification topic only |
| `WriteOrderProcessorLogs` | `logs:CreateLogStream`, `logs:PutLogEvents` | This function's log group only |

`ChangeMessageVisibility` is required because the event source mapping reports partial batch failures. The role has no dead-letter permissions. Inspecting or redriving a failed message is an operator action. The role cannot create log groups, and it cannot write to any other log group. Queue consumption and notification publishing are separate statements so a change to one does not widen the other.

## Network exposure

The queue, the dead-letter queue, and the topic are private to the AWS account. There is no public queue policy, no public topic policy, and no `Principal: "*"` allow. The function is not in a VPC and does not need a public IP or a NAT Gateway. Callers must have AWS credentials that are allowed to send to the queue.

## Data and logs

Orders are encrypted at rest with SQS-managed encryption. That does not use a customer-managed KMS key. The SNS topic does not add a KMS key either; a customer key would create extra cost and administration for a lab notification that contains an order ID, a product, a quantity, and an amount.

The function does not log the customer email or the raw message body. Successful logs contain the order ID, the SQS message ID, and `accepted`. Failed logs contain the message ID and a short error string. The SNS message also omits the email address. The address is still validated so a broken payload is rejected.

`simulateFailure` is a lab control on the message body. Anyone who can send to the queue can set it and force a message into the dead-letter queue. It is not authentication and it is not authorization. Remove it before this function processes real orders.

## Terraform state and files

State is local. `terraform.tfstate` will contain resource names, ARNs, the queue URL, and the email address if you set `sns_email_endpoint`. Anyone with the state file can see that information and can use it to target those resources if they also have AWS credentials. Keep the file on this machine, do not commit it, and do not copy it into tickets or chat.

`.gitignore` excludes state, the `.terraform/` directory, `terraform.tfvars`, variable auto-load files, the generated Lambda zip, and `node_modules/`. `.terraform.lock.hcl` is safe to commit after you run `terraform init`. It pins provider versions and does not contain account data.

`terraform.tfvars.example` contains an empty email and the same defaults as the variables. It is safe to commit. Copy it to `terraform.tfvars` before putting a real address in it.

## Duplicate processing

At-least-once delivery is a business-integrity issue as well as a reliability issue. A second publish can notify a customer twice about one order. This repository does not claim otherwise, and it does not include a store that would prevent it. See [architecture-decisions.md](architecture-decisions.md).
