const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");

const queueUrl = process.env.QUEUE_URL;
const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "eu-central-1";

async function main() {
  if (!queueUrl) {
    throw new Error("Set QUEUE_URL to the order queue URL printed by terraform apply");
  }

  const order = {
    orderId: `ORD-FAIL-${Date.now()}`,
    customerEmail: "customer@example.com",
    product: "Laptop",
    quantity: 1,
    amount: 1200,
    simulateFailure: true,
  };

  const client = new SQSClient({ region });
  const result = await client.send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify(order),
    }),
  );

  console.log(
    JSON.stringify({
      orderId: order.orderId,
      messageId: result.MessageId,
      result: "submitted",
      simulateFailure: true,
    }),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Failed to send order");
  process.exitCode = 1;
});
