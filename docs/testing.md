# Testing

Apply the Terraform stack yourself before these steps. The commands below read or create application messages only after that infrastructure exists. They are not a substitute for reading `terraform plan`.

## One-time local setup

From the repository root:

```bash
cd scripts
npm install
export AWS_PROFILE=your-cli-profile
export AWS_REGION=eu-central-1
export QUEUE_URL="paste-order_queue_url-here"
```

`npm install` downloads `@aws-sdk/client-sqs` so the scripts can run on your machine. It does not change AWS. The Lambda package does not use this directory.

`AWS_PROFILE` selects the named profile in your local AWS CLI configuration. If you use the default profile, you can omit it. The scripts pass the region and the queue URL only. They do not contain access keys.

`QUEUE_URL` must be the main order queue, not the dead-letter queue. Copy `order_queue_url` from the apply output.

## Commands

```bash
node send-orders.js 10
node send-orders.js 500
node send-failed-order.js
```

`send-orders.js` also reads `COUNT` when you do not pass a number. The accepted range is 1 to 1000, so a mistyped count cannot enqueue an unbounded test. Each run builds order IDs from the current time and a sequence, for example `ORD-1730000000000-0001`. IDs are unique across runs. They are not an idempotency lock.

`send-failed-order.js` sends one laptop order with `simulateFailure` set to boolean `true`. The order ID looks like `ORD-FAIL-<timestamp>`.

Expected results for the four scenarios, including dead-letter recovery, are in [failure-scenarios.md](failure-scenarios.md).

## Where to look

Use the same region as `aws_region`. Default names assume `project_name=ecommerce-order` and `environment=dev`.

Lambda logs:

1. Open CloudWatch, then Log groups.
2. Open `/aws/lambda/ecommerce-order-dev-order-processor`.
3. Open the latest stream.
4. Accepted work looks like `{"orderId":"ORD-...","messageId":"...","result":"accepted"}`.
5. Rejected work looks like `{"messageId":"...","result":"failed","error":"..."}`.

Lambda metrics, under the function's Monitor tab:

- `Invocations` rises for scenarios A and B.
- `Duration` stays well below the 10-second timeout for these messages.
- `Errors` stays at zero for the simulated failure, because the function reports that failure inside a successful invocation. Confirm scenario C with the log line and the dead-letter queue, not with the Lambda error count alone.

SQS metrics, on each queue's Monitoring tab:

- `ApproximateNumberOfMessagesVisible` shows the backlog. It should climb and then drain in scenario B, and it should end at zero on the main queue after scenario C moves the bad message.
- `ApproximateAgeOfOldestMessage` shows whether work is sitting. It grows while a failing message waits out the visibility timeout, then drops for that queue once the message moves or is deleted.
- The dead-letter queue's visible-message metric moves from zero to one in scenario C.

These metrics are already published by the services. This project does not create alarms or dashboards.

## Email notifications

Leave `sns_email_endpoint` empty unless you want mail. If you set it, AWS sends a confirmation message before any order notification arrives. An unconfirmed subscription proves nothing about scenario A. The SNS console shows the subscription as confirmed or pending.

## What a failed test usually means

- `Set QUEUE_URL` from a script: the variable is missing in that shell.
- `AccessDenied` from a script: the CLI profile cannot call `sqs:SendMessage` on this queue.
- No Lambda logs: the event source mapping is disabled, the function update failed, or you are looking at another region.
- The bad message never reaches the dead-letter queue: three visibility timeouts have not elapsed yet. Wait and refresh. With the default 60-second timeout, allow a few minutes.
- Two accepted logs for one order ID: the standard queue delivered the message more than once. The function has no idempotency store, so both deliveries publish.
