# Architecture decisions

Each service below was chosen because it removes a specific reliability failure in the current order workflow. The description of what the service does is secondary to that reason.

## Synchronous and coupled, compared with asynchronous and decoupled

In the current system, the component that receives the order calls notification and warehouse logic before it can answer. The caller waits for every dependency. Capacity is the capacity of the slowest call. A failure is immediately a failed order. A retry is a new attempt from the caller, with no durable buffer and no shared view of attempts that already ran.

In this design, the producer only has to get a durable acknowledgement from SQS. Processing happens later, at the rate Lambda and the queue allow. A notification failure retries the message without asking the customer to submit the order again. A message that cannot succeed leaves the main queue. Operators see backlog and errors without reading application servers.

The tradeoff is latency and certainty. The producer does not learn, in the same call, that the notification was sent. The platform also accepts at-least-once delivery: SQS Standard can present the same message more than once, so a side effect such as an SNS publish can happen twice. A synchronous database transaction with a unique order ID can be easier to reason about for a low-volume system. It does not absorb a Black Friday spike, and it still fails the order when a downstream call times out. For this business problem, the buffer and the isolated failure path matter more than a single synchronous response.

## Why Amazon SQS Standard

The order pipeline needs a durable buffer and competing, scale-out consumers. SQS Standard is built for that. Producers and consumers fail independently. The queue retains messages, hides them while a consumer works, and can move exhausted messages to a dead-letter queue.

A standard queue was chosen instead of a FIFO queue on purpose. FIFO adds ordering and a deduplication window, and it has lower throughput limits. This business problem is about surviving a spike and isolating bad messages, not about processing one customer's orders in a strict sequence. FIFO deduplication also would not make the SNS publish exactly-once. Deduplication only stops the queue from accepting a second send of the same message during the deduplication window. If the function publishes and then crashes before deleting the message, SQS delivers that same message again after the visibility timeout. Claiming exactly-once processing would be wrong for either queue type. The standard queue makes the at-least-once behavior obvious, which is the lesson this project is meant to show.

Amazon MQ or a self-managed broker would add instances, patching, and a cost floor. The lab does not need a broker feature that SQS lacks.

## Why a dead-letter queue and a maximum receive count of 3

Retries help with a short downstream timeout. They do not help with a message that will never validate, or with a lab message that is built to fail. Without a dead-letter queue, that message returns to the main queue forever and hides the healthy backlog.

Three receives are enough to ride out a brief processing error without parking a poison message for a long time. The visibility timeout is 60 seconds, so three attempts are spread over a few minutes rather than happening in a tight loop. Fourteen days of retention on the dead-letter queue gives an operator time to inspect and redrive the message. The main queue keeps messages for four days, which covers a sale weekend without storing them indefinitely.

The dead-letter queue has no consumer. Recovery is a deliberate operator action after the cause is fixed. An automatic consumer on the dead-letter queue would put poison messages back into processing.

## Why one Lambda function

The processing step is a single validation plus one notification. One function keeps the lab understandable and keeps the IAM surface small. The event source mapping scales the function up while the queue is deep and back down when the queue drains, without an EC2 fleet to size.

The function reports partial batch failures. A ten-message batch can contain one bad order and nine good ones. Failing the whole invocation would retry the nine good orders and could publish duplicate notifications for them. `ReportBatchItemFailures` lets SQS delete the successes and retry only the failures.

The event source mapping does not cap concurrency. The only downstream call in this lab is SNS, and a few hundred test messages do not need a limit. A production mapping that called a warehouse or payment API should set a maximum concurrency so a deep queue cannot open an unbounded number of concurrent calls.

Lambda was chosen over a container service or EC2 because the work is short, stateless, and idle most of the day. You pay for the invocations you run. There is no load balancer and no VPC, so there is no NAT Gateway.

A second function, placed between the queue and SNS, would separate "order accepted" from "notification sent". That split is useful when notification has a different failure rate from business validation. It is not useful here, because the only side effect is the notification itself. Adding a second function, a second queue, or Step Functions would add cost and moving parts without a second business system to protect.

## Why Amazon SNS

When processing succeeds, other parts of the business need to hear about it. SNS is a publish step, not a work queue. The function publishes one event. Subscribers can be added later without changing the processor. Email is optional and off by default so the lab does not send mail unless you ask it to.

SQS would be the wrong tool for this last step. A queue implies another worker and another retry policy. The notification is a fact about an order that already passed validation. A topic expresses that more directly.

Amazon EventBridge is a better fit when many independent products must filter a wide event bus. This project has one producer of one event type. SNS is the smaller choice. EventBridge could replace SNS later if subscribers need content-based routing.

## Why CloudWatch, and why there are no alarms

Lambda writes logs to CloudWatch whether or not you build dashboards. Creating the log group in Terraform sets a 14-day retention period. Without that resource, the default group never expires, and log storage grows after the lab is forgotten.

The metrics this project uses already exist for Lambda and SQS: invocations, errors, duration, visible message count, and age of the oldest message. Reading them in the console is enough to verify the four test scenarios. An alarm needs a threshold, a topic, and someone to receive it. Those are worth adding when an on-call rotation exists. They are extra resources for a portfolio lab, so they are not created.

## Why this IAM shape

The function runs as a role, not with keys stored in the package or the environment. The inline policy has three statements: consume the order queue, publish to the notification topic, and write log events to the known log group. Queue consumption and notification are separate statements so neither permission is wider than its resource.

The role cannot read or delete dead-letter messages. Redrive is an operator action with the operator's own credentials. The role also cannot create log groups or write logs for other functions.

## Why idempotency is documented and not built

A correct production processor records the order ID in a durable store before it publishes a customer-visible notification, and it treats a repeated order ID as a replay. DynamoDB is the usual AWS tool for that record. This project does not create a table.

The reason is scope and cost discipline. The business lesson here is decoupling, buffering, retry, and isolation. An idempotency table is a second design with its own capacity mode, encryption, and failure behavior. Leaving it out makes the remaining gap explicit: this pipeline can emit duplicate notifications. A portfolio reader should see that limit instead of a half-built lock that looks like exactly-once processing.

## Why these cost choices

EC2, RDS, NAT Gateway, and API Gateway do not appear because none of them is required to buffer a message, run a short function, or publish a notification. SQS-managed encryption is used instead of a customer-managed KMS key, because the lab does not need key administration and a customer key adds KMS requests. The SNS topic is left on the default AWS-owned encryption behavior for the same reason. Lambda stays at 256 MB and a 10-second timeout. The deployment package is only `index.js`; the Node.js 22 runtime already includes AWS SDK for JavaScript v3.

That SDK choice is acceptable for a lab and weaker for production. A future runtime update can change the SDK that is already on the host. A production build should pin `@aws-sdk/client-sns` inside the deployment package. The dependency is declared in `src/order-processor/package.json` so that later change has an obvious starting point. The Terraform archive step zips only `index.js`, so a local `npm install` in that directory is not uploaded.
