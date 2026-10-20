---
name: chargefy-payments
description: Implement Chargefy payments with links, hosted checkout, Chargefy.js, or Payment Intents, confirm outcomes through webhooks, and test in sandbox. Use when building or reviewing checkout, tokenizing cards, handling asynchronous payments, verifying events, or simulating approvals and declines.
---

# Payments, webhooks, and testing

Choose the requested flow, implement outcome confirmation, and validate relevant
states. Consult only the contracts needed for the task. API instructions and
tests work without MCP. Respond to the user in their preferred language.

## Choose the payment flow

Four paths, from least to most implementation effort. **When unsure, start with
hosted checkout**: it coordinates items, buyer details, methods, installments,
expiration, and webhooks; your backend decides what to sell and when to fulfill
the order.

| Path | When it fits | Effort |
| ---- | ------------ | ------ |
| **Payment Link** | A reusable offer without per-purchase backend work. A URL you share. | Low |
| **Hosted checkout** | One order at a time, using a ready-made Chargefy page. **Recommended default.** | Medium |
| **White-label checkout** | Payment must happen inside your product, with your brand and states. | High |
| **Payment Intents** | Your application already handles checkout and you only need to control the charge. | High |

Two questions resolve most cases: _does the offer change with each purchase?_
(no → link) and _must the payment interface be yours?_ (no → hosted).

Custom branding and domains are also available in hosted checkout. If the
request is only to show the platform's brand, follow
[platform branding and custom domain](https://docs.chargefy.io/platforms/branding-and-custom-domain).
If the user requested a custom interface with Chargefy.js, preserve that choice.

### Hosted checkout

The smallest valid request sends only `line_items`:

```bash
curl -X POST "https://api.chargefy.io/v1/checkout-sessions" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: order-8f4c2a" \
  -d '{ "line_items": [{ "price_id": "price_w9A2hszZXxVwxRaG", "quantity": 1 }] }'
```

Each item contains **exactly one** of `price_id` (catalog price) and `price_data`
(ad hoc price that exists only for that session).

Relevant response fields:

| Field | Use |
| ----- | --- |
| `url` | Redirect the browser here |
| `id` (`cs_...`) | Backend queries |
| `expires_at` | Fixed 24-hour lifetime; create another session afterward |
| `status` | Starts as `open` |
| `payment_status` | Starts as `unpaid` (or `no_payment_required` when nothing is due) |
| `client_secret` | Returns `null` for hosted checkout; access uses the `url`. |

Chargefy computes `mode`, totals, `expires_at`, and `url`; do not send them in
the request. Use a stable `Idempotency-Key` per order: a timeout retry returns
the same session instead of creating two.

To bring the buyer back, use absolute `success_url` and `cancel_url` values;
`{CHECKOUT_SESSION_ID}` in the URL is replaced with the session ID.

`checkout_experience.success_redirect` sets when the buyer leaves for
`success_url` after a confirmed payment:

| Value | Buyer experience |
| ----- | ---------------- |
| `{ "type": "automatic", "delay_seconds": 0 }` | Goes straight from the checkout to `success_url`, without the confirmation page |
| `{ "type": "automatic", "delay_seconds": 5 }` | Sees the confirmation, with **Redirect now**, and leaves after 1–60 seconds |
| `{ "type": "manual" }` | Sees the confirmation and leaves only after tapping **Continue** |

Omitted, the organization's default applies (10 seconds unless changed); a
session always returns the value it uses, and a payment link returns `null`
while it follows the organization. Pending Pix and boleto never redirect. In
`manual`, a buyer who closes the page never reaches `success_url`, so never tie
fulfillment to it.

### White-label checkout

The security boundary determines the design: card number and CVC are handled
**in the browser**, by [Chargefy.js](https://docs.chargefy.io/api/chargefy-js).
Your server never sees the PAN.

Immediate-payment sequence:

1. The backend creates or reuses the `customer` (`cus_...`).
2. The backend starts card setup (`setup_intent`, `seti_...`) and sends its `client_secret` to the frontend.
3. The browser loads `https://api.chargefy.io/v1/chargefy.js`, collects the card with the **publishable key** (`pk_...`), and returns a reusable `payment_method` (`pm_...`). The card number never passes through the backend.
4. The backend charges the saved `payment_method`.

Never send a secret key (`ch_...`) to the browser; use only `pk_...`. Always load
the script from its official origin, without a local copy, to receive security
fixes automatically.

### Direct Payment Intents

Use this when your application already manages the cart, items, and presentation
and only needs the financial attempt: send the final amount, currency, and
method, while managing states, retries, and buyer-facing translations yourself.
Direct creation supports cards and Pix; boleto originates in hosted checkout or
an invoice.

### Identify payments and attempts

`payment_intent.number` is an immutable six-character reference, unique within
the organization and environment. `charge.number` appends the attempt sequence,
with at least three digits; after `999`, it continues as `1000` without truncation.
These references are assigned by Chargefy: display them, but use the returned
`id` in API paths, cursors, and relationships. Do not send or derive IDs from `number`.

Example: a buyer pays BRL 100 under `J9N6R8`. Attempt `J9N6R8-001` fails;
`J9N6R8-002` succeeds. There is one Payment Intent and two Charges, not two
payments. Query each object using its own `pi_…` or `ch_…` ID. See
[payments and charges](https://docs.chargefy.io/payments/payments-vs-charges).
New payment and charge events include `number` in `data.object`; historical
event snapshots may lack it. Fetch the current resource by ID when needed.

### Implement with MCP and Chargefy for Platforms

MCP helps discover contracts, query resources, and create catalogs and links in
the authorized organization. Check `get_chargefy_account_info` and
`chargefy_api_details` before executing. Creating Checkout Sessions, setup
intents, and payment intents, and confirming charges require the public API;
card collection happens in the browser with Chargefy.js. Do not invent these
operations in MCP.

With **Chargefy for Platforms**, an MCP connection for the platform's owning
organization can query its child organizations. This does not authorize creating
their catalogs or links: the `organization` argument selects an already
authorized scope; it does not replace the HTTP `Organization` header. A link
created through MCP belongs to the scoped organization and has no platform origin.

To sell through a child organization with platform branding, implement backend
calls with the platform API key and the child's `Organization` header. In a
custom checkout, use the **platform's** publishable key in the browser and the
child's setup intent `client_secret`, in the same environment. The browser does
not send `Organization`. MCP does not accept platform API keys.

Read the full guides before implementing:

- [Custom checkout and Platforms examples](https://docs.chargefy.io/payments/build-white-label-checkout).
- [Create a hosted Checkout Session](https://docs.chargefy.io/payments/create-hosted-checkout-page).
- [How to use MCP](https://docs.chargefy.io/mcp/how-to-use).

### Common pitfalls

- **A redirect is not confirmation.** Treat the webhook as the source of truth; `success_url` only means the browser returned. See the webhook section below.
- **Pix and boleto are asynchronous.** Cards typically complete on confirmation; other methods remain pending until settlement, and the event completes the order.
- **Sessions expire in 24 hours.** Do not store the `url` for later reuse.
- **Payment methods can be selected in the request** with `payment_method_types`. When omitted, the session copies Checkout Builder defaults. The supplied list must be compatible with the items and mode.

### Further guidance

- Use `search_chargefy_documentation` to find the chosen flow's page.
- `chargefy_implementation_planner` prepares an integration plan without executing anything when the path is still undecided.
- To test each outcome (approved, declined, `processing`), use the sandbox scenarios below.

## Chargefy webhooks

Webhooks report resource changes independently of the buyer's return. A redirect
does not confirm payment. Also query the current resource when its state is
unclear or events arrive out of order.

### The contract

Your endpoint needs to:

1. Accept `POST` at an **HTTPS** URL.
2. Verify the signature **before** processing the body.
3. Return **2xx** within **20 seconds**.

Chargefy manages delivery queues, retries, secret rotation, and fan-out.

| Property | Value |
| -------- | ----- |
| Signature | Standard Webhooks (HMAC-SHA-256), secret `whsec_...` |
| Timeout per attempt | 20 seconds |
| Attempts | 9 (1 original + 8 retries) over approximately 3 days, with increasing backoff |
| Delivery guarantee | _At least once_; deduplicate by `event.id` |
| Order between different events | **Not** guaranteed |
| Wildcards (`charge.*`, `*`) | Not supported; subscribe to each exact type |

### Verify the signature

Each delivery includes these headers:

| Header | Content |
| ------ | ------- |
| `webhook-id` | Event ID (`evt_...`), matching the body's `id` |
| `webhook-timestamp` | Signature Unix timestamp **in seconds** |
| `webhook-signature` | `v1,<base64>`; may contain multiple space-separated signatures |

The signed message is `${webhook-id}.${webhook-timestamp}.${raw_body}`, and the
HMAC key is the **decoded bytes** of the secret's base64 portion after `whsec_`.
The secret format also follows the standard, so any Standard Webhooks library
works without adaptation: pass the entire secret, including the prefix.

**The main pitfall is the body.** Reserializing JSON breaks the signature.
Read the raw body before any framework parser.

```typescript
// Next.js (App Router)
import { NextRequest, NextResponse } from "next/server";
import { Webhook } from "svix";

const wh = new Webhook(process.env.CHARGEFY_WEBHOOK_SECRET!); // whsec_...

export async function POST(req: NextRequest) {
  const body = await req.text(); // raw body; never use req.json() here
  let evt;
  try {
    evt = wh.verify(body, {
      "webhook-id": req.headers.get("webhook-id")!,
      "webhook-timestamp": req.headers.get("webhook-timestamp")!,
      "webhook-signature": req.headers.get("webhook-signature")!,
    });
  } catch {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  // Enqueue durably and respond quickly; perform heavy processing afterward.
  await enqueue(evt);
  return NextResponse.json({ received: true });
}
```

In Express, mount this route with `express.raw({ type: "application/json" })`
before the global `express.json()` middleware.

### Deduplicate and do not rely on order

`event.id` is stable per event and equals the `webhook-id` header. Store it in a
table with a uniqueness constraint: if it already exists, return `200` and do
**not** process it again.

Different events have no guaranteed order, and `data.object` is a snapshot at the
time of the event; it may arrive outdated. Before applying a terminal transition,
fetch the resource by ID and do not let a failure downgrade a payment already
`succeeded` or a session already `paid`.

### Choose event types

Subscribe to the **business outcome**, not the path: the same
`payment.intent.succeeded` confirms a payment from checkout, a link, or the API.

| To learn when… | Listen to |
| -------------- | --------- |
| A payment is confirmed | `payment.intent.succeeded` |
| A charge is captured / declined | `charge.succeeded`, `charge.failed` |
| A Checkout Session completes | `checkout.session.completed` |
| An asynchronous checkout payment succeeds | `checkout.session.async.payment.succeeded` |
| An invoice is paid / fails | `invoice.paid`, `invoice.payment.failed` |
| A subscription changes | `subscription.updated` |

The `type` follows `namespace.action`, always separated by periods. The full
catalog is at `/api-reference/events/types`; consult the
[reference](https://docs.chargefy.io/api-reference/events/types) rather than guessing names.

### Respond correctly

- **Persist before acknowledging.** Store the event or job in a durable queue before returning `2xx`; if storage fails, return an error so delivery can retry. Heavy work inside the 20-second window can time out, counting as a failure and triggering redelivery of an already received event.
- **Ignored events still deserve `200`.** For unneeded types, duplicates, or unknown organizations, acknowledge and silently discard. Reserve `4xx`/`5xx` for actual processing failures.
- An endpoint down for hours, up to approximately 3 days, recovers automatically when it returns. After 9 attempts, delivery becomes permanently failed and requires manual redelivery from the dashboard.

### Rotate secrets without a rejection window

Resetting the secret takes effect immediately and breaks in-flight deliveries.
To change it without losing events, register a temporary endpoint with the same
URL and events, accept both secrets on the server (try one, then the other),
confirm `2xx` on the new endpoint, and only then remove the old one. During the
transition, each event arrives twice; deduplication by `event.id` handles this.

### Test locally

Expose the port through an HTTPS tunnel (`ngrok http 3000` or `lt --port 3000`)
and register the generated URL as a test-mode endpoint. To trigger failure events
on demand, use the cards in the sandbox section below.

### When reviewing an endpoint, check

- [ ] Signature verification uses the raw body, with no preceding parser.
- [ ] Signature failure returns `401` without processing.
- [ ] Deduplication uses `event.id` with database uniqueness.
- [ ] Responses return `2xx` quickly; processing is asynchronous.
- [ ] No logic depends on delivery order.
- [ ] The secret is in an environment variable, never in code.

Transport details, retry schedules, and platform fan-out are covered in
[webhook delivery](https://docs.chargefy.io/integrate/webhooks/delivery).
Read the guide directly or use `search_chargefy_documentation` if MCP is available.

## After-sale operations

For capture, attempt cancellation, refunds, disputes, or reconciliation, consult
the current resource contract before implementing. Do not treat a dispute as a
refund or an approval as bank settlement. Do not execute real financial mutations
merely to test an integration.

- [Asynchronous capture](https://docs.chargefy.io/payments/asynchronous-capture).
- [Cancel an attempt](https://docs.chargefy.io/payments/cancel-payment-attempt).
- [Refund a payment](https://docs.chargefy.io/payments/refund-payment).
- [Respond to disputes](https://docs.chargefy.io/payments/respond-to-disputes).
- [Reconcile payments](https://docs.chargefy.io/payments/reconcile-payments).

{/* BEGIN GENERATED SANDBOX */}
{/* Generated by `pnpm claude-plugin:build` from sandbox-card-scenarios.js and payment-decline-codes.ts. Do not edit manually. */}

## Test payments in the Chargefy sandbox

The sandbox uses the same endpoints, objects, and webhooks as production, with
simulated money. The key used in the request selects the environment:
`ch_test_` creates and queries test data (`livemode: false`), while
`ch_live_` creates and queries production data.

The numbers on this page select payment outcomes **only in test mode**.
In live mode, they are treated as ordinary cards.

### How to use

- Use any three-digit CVC and a future expiration date.
- Unknown cards in test mode are **approved** by default.
- Supported in hosted checkout, Chargefy.js, invoice payment pages, and card
  update forms.
- A decline ends the attempt, not the intent: the Payment Intent returns to
  `requires_payment_method` with the reason in `last_payment_error`, and
  the same intent accepts another confirmation. Through the API, a declined
  confirmation returns 402 with the same `code` and the intent in
  `error.payment_intent`. Use this to test a decline followed by a retry.
- `processing` and `pending` are not final outcomes. Do not treat the
  absence of an error as approval: wait for the webhook.

The stable code is in `payment_error.code`, with guidance in
`payment_error.advice_code`. The **Retryable** column below indicates whether
repeating the same charge could change the outcome; a non-retryable decline
requires another payment method.

### Success and statuses

| Card               | Scenario           | Resulting status   |
| ------------------ | ------------------ | ------------------ |
| `4242424242424242` | `succeeded`        | `succeeded`        |
| `4000000000003220` | `requires_capture` | `requires_capture` |
| `4000009000000425` | `processing`       | `processing`       |
| `4000009000000433` | `pending`          | `pending`          |
| `4000009000000649` | `save_declined`    | `succeeded`        |

### Saved cards and reuse

These approve the hosted checkout charge, including a subscription's first
charge, which also saves the card. Their special behavior appears when the
saved card is charged again outside checkout: subscription renewal, a funnel's
next offer, an invoice payment with a saved card, or confirmation with a saved
`payment_method`.

- `4000009000000623` — Approves the checkout charge. On the next charge using the saved card, returns to `requires_payment_method` with `payment_error.code` set to `single_use_card`.
- `4000009000000631` — Approves the checkout charge. On the next charge using the saved card, stays in `processing`: wait for the webhook and do not start another attempt.

### Simulated failures

Each card returns `requires_payment_method` with the row's `payment_error`.
In production, some codes originate during capture, tokenization, or refunds.
In sandbox, the card exercises the public contract and message, not the
operational stage that originally produced the error.

#### Issuer decline (`issuer_declined`)

| Card               | `payment_error.code`        | Retryable | Message                                                        |
| ------------------ | --------------------------- | --------- | -------------------------------------------------------------- |
| `4000000000009995` | `insufficient_funds`        | yes       | The card has insufficient funds to complete the purchase.      |
| `4000009000000011` | `do_not_honor`              | yes       | The issuer declined the transaction without a specific reason. |
| `4000000000000002` | `generic_decline`           | no        | The card was declined.                                         |
| `4000009000000029` | `call_issuer`               | yes       | The card was declined. The cardholder must contact the issuer. |
| `4000009000000037` | `card_velocity_exceeded`    | yes       | The card exceeded its balance, credit, or transaction limit.   |
| `4000009000000045` | `invalid_amount`            | no        | The transaction amount is not allowed for this card.           |
| `4000009000000052` | `invalid_account`           | yes       | The account linked to the card is invalid or does not exist.   |
| `4000009000000060` | `transaction_not_permitted` | no        | This type of transaction is not permitted for the cardholder.  |
| `4000009000000078` | `service_not_allowed`       | yes       | This transaction is not permitted for the card.                |
| `4000009000000086` | `card_not_supported`        | no        | The card does not support this type of purchase.               |
| `4000009000000094` | `currency_not_supported`    | yes       | The card does not support the transaction currency.            |
| `4000009000000102` | `card_not_activated`        | yes       | The card has not been activated.                               |
| `4000009000000110` | `authentication_required`   | no        | The transaction requires cardholder authentication.            |
| `4000009000000128` | `reenter_transaction`       | yes       | The issuer could not process the transaction. Try again.       |
| `4000009000000136` | `approve_with_id`           | yes       | The payment could not be authorized.                           |
| `4000009000000144` | `not_permitted`             | yes       | The requested operation is not supported by the card.          |
| `4000009000000409` | `testmode_decline`          | yes       | A test card triggered a decline.                               |
| `4000009000000417` | `payment_failed`            | yes       | Payment failed.                                                |

#### Processing error (`processing_error`)

| Card               | `payment_error.code`              | Retryable | Message                                                      |
| ------------------ | --------------------------------- | --------- | ------------------------------------------------------------ |
| `4000009000000441` | `authentication_not_available`    | no        | Cardholder authentication is not available for this payment. |
| `4000009000000342` | `issuer_unavailable`              | yes       | The card issuer could not be reached. Try again.             |
| `4000009000000359` | `routing_error`                   | yes       | The transaction could not be routed to the issuer.           |
| `4000009000000367` | `duplicate_transaction`           | yes       | A duplicate transaction was detected.                        |
| `4000009000000375` | `try_again_later`                 | yes       | The payment could not be processed. Try again later.         |
| `4000009000000383` | `connection_error`                | yes       | Could not reach the payment provider. Please try again.      |
| `4000009000000391` | `customer_unavailable`            | yes       | Customer could not be identified for the charge.             |
| `4000000000000119` | `processing_error`                | yes       | An error occurred while processing the payment. Try again.   |
| `4000009000000532` | `merchant_not_approved`           | no        | The merchant account is not available for this payment.      |
| `4000009000000540` | `authorization_expired`           | no        | The authorization expired before capture.                    |
| `4000009000000557` | `capture_method_not_supported`    | no        | The selected capture method is not supported.                |
| `4000009000000565` | `charge_already_captured`         | no        | The payment was already captured.                            |
| `4000009000000573` | `charge_already_refunded`         | no        | The payment was already refunded.                            |
| `4000009000000581` | `partial_refund_not_supported`    | no        | This payment does not support partial refunds.               |
| `4000009000000599` | `payment_intent_unexpected_state` | no        | The operation is not allowed in the payment's current state. |
| `4000009000000607` | `refund_period_expired`           | no        | The refund window for this payment has expired.              |
| `4000009000000615` | `refund_state_mismatch`           | no        | The refund state could not be reconciled.                    |

#### Invalid data (`invalid`)

| Card               | `payment_error.code`                | Retryable | Message                                                  |
| ------------------ | ----------------------------------- | --------- | -------------------------------------------------------- |
| `4000009000000458` | `new_account_information_available` | yes       | Updated card or account information is required.         |
| `4000000000000069` | `expired_card`                      | no        | The card has expired.                                    |
| `4000000000000127` | `incorrect_cvc`                     | no        | The card security code (CVC) is incorrect.               |
| `4000009000000151` | `incorrect_number`                  | no        | The card number is incorrect.                            |
| `4000009000000169` | `invalid_number`                    | no        | The card number is invalid or the issuer does not exist. |
| `4000009000000177` | `incorrect_pin`                     | yes       | The card PIN is incorrect.                               |
| `4000009000000185` | `invalid_pin`                       | yes       | The card PIN is invalid.                                 |
| `4000009000000193` | `pin_try_exceeded`                  | yes       | The allowable number of PIN tries was exceeded.          |
| `4000009000000201` | `invalid_transaction`               | yes       | The transaction is invalid.                              |
| `4000009000000219` | `no_payment_method`                 | yes       | No payment method available to charge.                   |
| `4000009000000227` | `card_unusable`                     | yes       | The saved card could not be used.                        |
| `4000009000000235` | `payment_method_mismatch`           | yes       | The payment method does not belong to this customer.     |
| `4000009000000466` | `invalid_cvc`                       | yes       | The card security code has an invalid format.            |
| `4000009000000474` | `invalid_expiry_month`              | yes       | The card expiration month has an invalid format.         |
| `4000009000000482` | `invalid_expiry_year`               | yes       | The card expiration year has an invalid format.          |
| `4000009000000490` | `invalid_name`                      | yes       | The cardholder name is invalid.                          |
| `4000009000000508` | `invalid_request`                   | yes       | The payment request contains invalid data.               |
| `4000009000000516` | `invalid_token`                     | yes       | The card token is invalid or expired.                    |

#### Blocking and prevention (`blocked`)

| Card               | `payment_error.code`               | Retryable | Message                                                     |
| ------------------ | ---------------------------------- | --------- | ----------------------------------------------------------- |
| `4000009000000243` | `lost_card`                        | no        | The card was reported lost.                                 |
| `4000009000000250` | `stolen_card`                      | no        | The card was reported stolen.                               |
| `4000009000000268` | `pickup_card`                      | no        | The card cannot be used (retain card).                      |
| `4000009000000276` | `restricted_card`                  | no        | The card is restricted.                                     |
| `4000009000000284` | `fraudulent`                       | no        | The transaction was flagged as suspected fraud.             |
| `4000009000000292` | `security_violation`               | yes       | The transaction was declined for a security violation.      |
| `4000009000000300` | `stop_payment_order`               | yes       | A stop payment order applies to this card.                  |
| `4000009000000318` | `revocation_of_authorization`      | no        | Authorization for this card has been revoked.               |
| `4000009000000326` | `revocation_of_all_authorizations` | no        | All authorizations for this card have been revoked.         |
| `4000009000000334` | `transaction_not_allowed`          | no        | The transaction is not allowed.                             |
| `4000009000000524` | `single_use_card`                  | no        | The card is single-use or not supported for future charges. |

### When a scenario is not listed here

Consult the [Sandbox](https://docs.chargefy.io/api-reference/sandbox) page for
deterministic emails, account activation, and behavior before registration
approval.
{/* END GENERATED SANDBOX */}
