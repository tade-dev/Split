// Plan Task 14: can PayPal pay a *personal* sandbox account directly?
// Operator-only, not imported by src/. Needs PayPal sandbox credentials in
// api/.env (the rest of loadEnv's required values can be placeholders).
//
//   npx tsx scripts/payee-spike.ts <payee-sandbox-email>
//     creates the order and prints the payer-action link to approve as the buyer
//   npx tsx scripts/payee-spike.ts --capture <paypal-order-id>
//     captures it once approved
//
// Record the printed results under *PayPal* in docs/verified-facts.md.
import 'dotenv/config';
import { loadEnv } from '../src/env.js';
import { makePayPalClient } from '../src/paypal/client.js';

type Order = {
  id: string;
  status: string;
  links?: { rel: string; href: string }[];
  purchase_units?: { payments?: { captures?: { id: string; status: string }[] } }[];
};

const env = loadEnv();
const call = makePayPalClient(env);
const [first, second] = process.argv.slice(2);

if (first === '--capture' && second) {
  const captured = (await call(`/v2/checkout/orders/${second}/capture`, {
    method: 'POST',
    requestId: 'capture-spike',
    body: {},
  })) as Order;
  const capture = captured.purchase_units?.[0]?.payments?.captures?.[0];
  console.log(JSON.stringify({
    order: captured.id,
    orderStatus: captured.status,
    captureId: capture?.id ?? null,
    captureStatus: capture?.status ?? null,
  }, null, 2));
} else if (first && first.includes('@')) {
  const created = (await call('/v2/checkout/orders', {
    method: 'POST',
    requestId: `create-spike-${Date.now()}`,
    body: {
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: 'spike',
        custom_id: 'org:split:participant',
        amount: { currency_code: 'GBP', value: '39.23' },
        payee: { email_address: first },
        description: 'Your share of Friday dinner (Little Bao House)',
      }],
      payment_source: {
        paypal: {
          experience_context: {
            brand_name: 'Split',
            locale: 'en-GB',
            user_action: 'PAY_NOW',
            shipping_preference: 'NO_SHIPPING',
            return_url: `${env.PUBLIC_BASE_URL}/v1/paypal/return`,
            cancel_url: `${env.PUBLIC_BASE_URL}/v1/paypal/cancel`,
          },
        },
      },
    },
  })) as Order;
  const link = created.links?.find((l) => l.rel === 'payer-action');
  console.log(JSON.stringify({
    order: created.id,
    status: created.status,
    approvalRel: link?.rel ?? null,
    approvalUrl: link?.href ?? null,
  }, null, 2));
  console.log(`\nApprove as the sandbox buyer, then: npx tsx scripts/payee-spike.ts --capture ${created.id}`);
} else {
  console.error('Usage: npx tsx scripts/payee-spike.ts <payee-email> | --capture <order-id>');
  process.exit(1);
}
