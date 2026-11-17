# Failure scenarios

Run these only after you have applied the Terraform configuration yourself. The producer setup is in [testing.md](testing.md). Queue names below use the default prefix `ecommerce-order-dev`.

SQS Standard can deliver a message more than once. A successful scenario can still show two notifications for one order if a delivery is duplicated. That is not a failed test. It is the delivery behavior this project is intended to make visible.

## Scenario A — normal processing

Send 10 valid orders:

```bash
node send-orders.js 10
```

What you should see:

- The script prints `submitted` and an SQS message ID for each order.
- The Lambda log group shows one `accepted` line per processed message, with that order's `orderId`.
- The main queue returns to approximately zero visible messages.
- The dead-letter queue stays empty.
- If you set `sns_email_endpoint` and confirmed the subscription, the mailbox receives one notification per successful publish. Duplicate delivery can produce an extra copy.

## Scenario B — traffic spike

Send 500 valid orders:

```bash
node send-orders.js 500
```

What you should see:

- The script finishes when SQS has accepted the messages, which can be earlier than Lambda finishing the work.
- `ApproximateNumberOfMessagesVisible` on the order queue rises, then falls back toward zero.
- Lambda `Invocations` increases. With a batch size of 10, a few hundred invocations is enough for 500 messages. The exact count varies because batches are not always full.
- Messages are processed without adding a server or changing the producer.
- The dead-letter queue stays empty unless a message was actually invalid.

This scenario shows the buffer. The producer is not limited by how fast the function publishes notifications.

## Scenario C — downstream processing failure

Send one order that the function is built to reject:

```bash
node send-failed-order.js
```

What you should see:

- The script still reports `submitted`. SQS accepted the message. Acceptance and processing are different steps.
- The Lambda log shows `failed` and `Simulated processing failure` for that message ID.
- The message remains in the main queue across retries. The visibility timeout is 60 seconds, so the receives are not immediate.
- After three failed receives, the message is in the dead-letter queue and no longer in the main queue.
- CloudWatch `Errors` for the function does not have to increase. The handler catches the failure and returns it as a partial batch failure, so the invocation itself succeeds. Use the log line and the dead-letter queue depth as the proof.

An invalid JSON body or a missing required field follows the same retry and dead-letter path.

## Scenario D — recovery

Do this after you know why the message failed. A managed redrive moves the original body unchanged. It does not edit JSON. Redriving the Scenario C message while `simulateFailure` is still `true` produces three more failures and returns the message to the dead-letter queue.

1. Open the SQS console in the same region as the stack.
2. Open `ecommerce-order-dev-order-dlq` and poll for messages.
3. Read the body. Confirm the `orderId`. The Scenario C message has `simulateFailure` set to `true`.
4. Pick the recovery that matches the cause.
   - The message is only a lab failure. Delete it after you inspect it. It was never a real order, so there is nothing to replay.
   - The function has a defect that rejects valid orders. Fix and deploy the function first. Then start a dead-letter redrive and select the source queue `ecommerce-order-dev-orders`.
   - The stored body is wrong and must change. Copy the body, correct it, send the corrected JSON to the source queue, and delete the dead-letter copy. Use this manual replay when the payload itself is the defect. The managed redrive task cannot change the body.
5. Watch the Lambda logs. A corrected message logs `accepted`. The dead-letter visible count returns to zero once the message is deleted or successfully processed. A message that still fails comes back after three receives.

The operator uses their own IAM permissions. The Lambda role cannot read the dead-letter queue. An administrator in a lab account can do this from the console. A narrower operator policy needs permission to receive and delete messages on the dead-letter queue, send messages to the source queue, and start the message move task.

No extra queue, function, or alarm is created for this scenario. Recovery is an operation, not another piece of the platform.
