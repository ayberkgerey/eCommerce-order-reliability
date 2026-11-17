const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");

const queueUrl = process.env.QUEUE_URL;
const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "eu-central-1";

const PRODUCTS = [
  { product: "Laptop", amount: 1200 },
  { product: "Keyboard", amount: 80 },
  { product: "Monitor", amount: 350 },
  { product: "Headphones", amount: 150 },
  { product: "Mouse", amount: 40 },
];

function parseCount(argv) {
  const raw = argv[2] || process.env.COUNT || "10";
  const count = Number(raw);

  if (!Number.isInteger(count) || count < 1 || count > 1000) {
    throw new Error("Order count must be an integer from 1 to 1000");
  }

  return count;
}

function buildOrder(runId, index) {
  const sample = PRODUCTS[(index - 1) % PRODUCTS.length];

  return {
    orderId: `ORD-${runId}-${String(index).padStart(4, "0")}`,
    customerEmail: `customer${index}@example.com`,
    product: sample.product,
    quantity: 1,
    amount: sample.amount,
    simulateFailure: false,
  };
}

async function main() {
  if (!queueUrl) {
    throw new Error("Set QUEUE_URL to the order queue URL printed by terraform apply");
  }

  const count = parseCount(process.argv);
  const client = new SQSClient({ region });
  const runId = Date.now();

  for (let index = 1; index <= count; index += 1) {
    const order = buildOrder(runId, index);
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
      }),
    );
  }

  console.log(JSON.stringify({ submitted: count }));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Failed to send orders");
  process.exitCode = 1;
});
