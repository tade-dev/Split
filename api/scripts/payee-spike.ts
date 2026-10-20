// The PayPal payee spike (spec §5, plan Task 14). Operator-only: nothing in
// src/ imports this. Reads api/.env for the sandbox credentials.
//
//   npx tsx scripts/payee-spike.ts --payee <personal sandbox email>
//   npx tsx scripts/payee-spike.ts --capture <order id>
//
// Approve the printed payer-action link as the sandbox buyer between the two.
import 'dotenv/config';
import { loadEnv } from '../src/env.js';
import { makePayPalClient } from '../src/paypal/client.js';

type Link = { href: string; rel: string };

const args = process.argv.slice(2);
const flag = (name: string) => {
  const i = args.indexOf(name);
  return i === -1 ? undefined : args[i + 1];
};

const env = loadEnv();
const call = makePayPalClient(env);
console.log(`PayPal: ${env.PAYPAL_ENV} (${env.PAYPAL_API_BASE})`);

const captureId = flag('--capture');
const payee = flag('--payee');

if (captureId) {
  const captured = (await call(`/v2/checkout/orders/${captureId}/capture`, {
    method: 'POST',
    body: {},
    requestId: 'capture-spike',
  })) as {
    status: string;
    purchase_units?: {
      payee?: { email_address?: string; merchant_id?: string };
      payments?: { captures?: { id: string; status: string; amount: { value: string } }[] };
    }[];
  };
  const unit = captured.purchase_units?.[0];
  const capture = unit?.payments?.captures?.[0];
  console.log(JSON.stringify({
    order: captureId,
    status: captured.status,
    capture: capture && { id: capture.id, status: capture.status, value: capture.amount.value },
    payee: unit?.payee,
  }, null, 2));
} else if (payee) {
  const order = (await call('/v2/checkout/orders', {
    method: 'POST',
    body: {
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: 'spike',
        custom_id: 'org:split:participant',
        description: 'Your share of Friday dinner (Little Bao House)',
        amount: { currency_code: 'GBP', value: '39.23' },
        payee: { email_address: payee },
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
  })) as { id: string; status: string; links?: Link[] };
  const action = order.links?.find((l) => l.rel === 'payer-action');
  console.log(JSON.stringify({
    order: order.id,
    status: order.status,
    rels: order.links?.map((l) => l.rel),
    approve: action?.href,
  }, null, 2));
  console.log(`\nApprove as the sandbox buyer, then: npx tsx scripts/payee-spike.ts --capture ${order.id}`);
} else {
  console.error('Usage: --payee <sandbox email> | --capture <order id>');
  process.exit(1);
}
