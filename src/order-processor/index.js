const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const sns = new SNSClient({});
const topicArn = process.env.ORDER_TOPIC_ARN;

const REQUIRED_FIELDS = ["orderId", "customerEmail", "product", "quantity", "amount"];

function validateOrder(order) {
  if (order === null || typeof order !== "object" || Array.isArray(order)) {
    throw new Error("Order message must be a JSON object");
  }

  for (const field of REQUIRED_FIELDS) {
    const value = order[field];
    if (value === undefined || value === null || value === "") {
      throw new Error(`Missing required field: ${field}`);
    }
  }

  if (typeof order.orderId !== "string") {
    throw new Error("orderId must be a string");
  }

  if (typeof order.customerEmail !== "string" || !order.customerEmail.includes("@")) {
    throw new Error("customerEmail must be an email address");
  }

  if (typeof order.product !== "string") {
    throw new Error("product must be a string");
  }

  if (!Number.isInteger(order.quantity) || order.quantity < 1) {
    throw new Error("quantity must be a positive integer");
  }

  if (typeof order.amount !== "number" || !Number.isFinite(order.amount) || order.amount < 0) {
    throw new Error("amount must be a non-negative number");
  }
}

async function publishAcceptedOrder(order) {
  if (!topicArn) {
    throw new Error("ORDER_TOPIC_ARN is not configured");
  }

  await sns.send(
    new PublishCommand({
      TopicArn: topicArn,
      Subject: `Order accepted ${order.orderId}`.slice(0, 100),
      Message: JSON.stringify({
        orderId: order.orderId,
        product: order.product,
        quantity: order.quantity,
        amount: order.amount,
        status: "ACCEPTED",
      }),
    }),
  );
}

async function processRecord(record) {
  let order;

  try {
    order = JSON.parse(record.body);
  } catch {
    throw new Error("Order body is not valid JSON");
  }

  validateOrder(order);

  // Development switch only. A true value forces this message to fail,
  // be retried, and eventually move to the dead-letter queue.
  if (order.simulateFailure === true) {
    throw new Error(`Simulated processing failure for order ${order.orderId}`);
  }

  await publishAcceptedOrder(order);

  console.log(
    JSON.stringify({
      orderId: order.orderId,
      messageId: record.messageId,
      result: "accepted",
    }),
  );
}

// SQS Standard delivers at least once. A successful publish followed by a
// timeout can run this handler again for the same order. This function does
// not provide exactly-once processing.
exports.handler = async (event) => {
  const batchItemFailures = [];

  for (const record of event.Records ?? []) {
    try {
      await processRecord(record);
    } catch (error) {
      console.error(
        JSON.stringify({
          messageId: record.messageId,
          result: "failed",
          error: error instanceof Error ? error.message : "Unknown processing error",
        }),
      );
      if (record.messageId) {
        batchItemFailures.push({ itemIdentifier: record.messageId });
      }
    }
  }

  return { batchItemFailures };
};
