# Business problem

An e-commerce company accepts thousands of orders during short, high-traffic events. Black Friday is the example used in this project. The checkout experience can stay up while the work behind it falls over, because accepting an order currently does more than record the order.

## What fails today

The current flow treats order intake, customer notification, and warehouse handoff as one synchronous operation.

- Those steps are tightly coupled. The order is not accepted unless notification and warehouse handling also succeed.
- A timeout or a brief outage in one downstream system fails the whole workflow, including orders that the business could have accepted and completed later.
- A traffic spike is applied directly to every downstream system. There is no buffer, so the slowest dependency sets the capacity of the entire process.
- Failed orders are difficult to track. There is no separate place for messages that will not succeed, and operators cannot easily tell a temporary error from a permanent one.
- Retrying a failed operation can process the same order twice. The platform has no durable record of work it has already completed.
- Operators have poor visibility. They cannot see how deep the backlog is, how old the oldest order is, or which processing attempts failed.

## What the business needs

The replacement workflow has to keep these properties during a sale event:

- Intake must succeed even when notification or a later processing step is temporarily unavailable.
- A burst of orders must wait in a buffer instead of overwhelming the processor.
- Processing must be asynchronous, so the producer does not hold a request open until every downstream step finishes.
- Temporary failures must be retried without a person resubmitting each order.
- Messages that still fail must leave the main flow so they do not block healthy orders.
- Operators must be able to see failures and backlog with CloudWatch logs and metrics.

## What this project deliberately does not do

There is no payment gateway and no warehouse system. The Lambda function validates the order and publishes a notification. That is enough to show the reliability pattern: buffering, asynchronous processing, partial batch failure, retries, a dead-letter queue, and operational visibility.

The design also does not claim that each order is processed once. SQS Standard can deliver the same message more than once. A production implementation of this business process needs a persistent idempotency key, for example the order ID stored before any customer-visible side effect. That store is out of scope for this lab and is called out in the architecture decisions.
