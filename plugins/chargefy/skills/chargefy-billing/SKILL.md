---
name: chargefy-billing
description: Implement recurring billing with Chargefy subscriptions, invoices, trials, proration, usage billing, schedules, recovery, cancellation, and the customer portal. Use when creating or changing plans, synchronizing access, importing subscriptions, or handling failed renewals.
---

# Chargefy subscriptions and billing

A Subscription represents the agreement; an Invoice represents each cycle's bill.
Agree on trial, plan change, payment failure, and cancellation policies with the
partner before selecting parameters. Preserve decisions already given in the request.
Respond to the user in their preferred language.

## Create the agreement

1. Identify the organization, environment, Customer, and offer. Use a recurring catalog Price or `price_data` supported by the endpoint. Items share a currency and billing cadence.
2. Choose hosted checkout or API creation based on the requested experience. Checkout computes `mode` from its items; do not send it.
3. For automatic collection, prepare the payment method through the documented flow. Do not send raw card data through your server.
4. Track the returned status and events: creation may return `incomplete`, `trialing`, or `active`. Creating a subscription does not prove that a payment occurred.

Guides: [create subscriptions](https://docs.chargefy.io/payments/create-subscriptions),
[activate incomplete subscriptions](https://docs.chargefy.io/payments/activate-incomplete-subscriptions),
and [create through the API](https://docs.chargefy.io/api-reference/subscriptions/create).

## Trials and product access

A trial may come from the price or be set on the agreement, according to the schema.
Decide what happens when it ends without a card: issue an invoice, pause, or cancel.
Listen to `subscription.trial.will.end` for reminders; use the current status to
confirm the final transition.

For a card that cannot be saved for future charges, hosted checkout requires
**Allow on subscriptions** and **Allow on free trials** to be enabled to start
a free trial with that card. Turning off the subscription setting also blocks
the trial case, even if its saved preference remains on. With both enabled,
checkout starts the trial without charging or saving the card, and the first
payment is collected by invoice at trial end. See
[billing settings](https://docs.chargefy.io/payments/payment-settings).

The trial reminder setting determines the lead time of the email and
`subscription.trial.will.end` when scheduled. A value of `0` disables the email
while the webhook remains scheduled three days before trial end. Do not assume
that disabling customer emails suppresses integration events.

| Status       | Integration decision                                                   |
| ------------ | ---------------------------------------------------------------------- |
| `incomplete` | Wait for the first invoice; do not treat it as a paid subscription     |
| `trialing`   | Grant the access defined for the trial                                 |
| `active`     | Synchronize the current plan and period                                |
| `past_due`   | Apply the product's grace-period policy and track recovery             |
| `unpaid`     | Automatic attempts are exhausted; invoices may remain open             |
| `paused`     | Follow the documented resume flow after a trial without a card         |
| `canceled`   | The agreement has ended; a returning customer needs a new subscription |

Read about [trials](https://docs.chargefy.io/payments/subscription-trial) and
[recovery](https://docs.chargefy.io/payments/revenue-recovery).
Do not automatically cancel on the first `invoice.payment.failed`.

A renewal can emit `invoice.payment.failed` without a Charge when it starts
without a saved card: the Invoice stays `open`, with `attempt_count: 0` and
`next_payment_attempt: null`. This case sends a missing-card notice when enabled
and does not start or exhaust a retry schedule. The current email setting and
link destination apply even to invoices already in recovery; retry dates and
the final action remain those captured when recovery began.

## Change the plan or quantity

Use the [preview and proration guide](https://docs.chargefy.io/payments/update-subscriptions-with-proration)
before applying a change that charges a difference.

- `create_prorations`: adjustment items go on the next invoice.
- `always_invoice`: the difference generates an invoice immediately.
- `none`: change without creating prorations.
- For an upgrade conditional on immediate payment, check `pending_if_incomplete`: items take effect only after the invoice is paid; track `pending_update` and its expiration.
- A downgrade may create credit for future invoices; credit is not a card refund.

Example: "Upgrade Pro from BRL 99 to the BRL 199 plan today, only if the difference
is paid." Fetch a preview, show the actual amount, and use the pending change
supported by the endpoint. Do not assume a fixed BRL 100 difference: it depends
on the period, quantity, discounts, and credits.

## Usage, schedules, and migration

| Need                     | Where to confirm the contract and decision                                                                                                                                                                           |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Charge for consumption   | [Usage records](https://docs.chargefy.io/api-reference/subscription-item-usage-records/create): record usage on the correct item and check the period, aggregation, and idempotency; do not invent a meters endpoint |
| Phases or a future start | [Subscription schedules](https://docs.chargefy.io/api-reference/subscription-schedules/create): confirm phases, dates, and end behavior                                                                              |
| Import agreements        | [Import](https://docs.chargefy.io/payments/import-subscriptions): preserve the next billing date and external IDs; avoid charging for the same period in both systems                                                |
| One-time billing         | [Invoices](https://docs.chargefy.io/payments/invoices): choose automatic collection or customer payment without creating recurrence                                                                                  |
| Self-service             | [Portal](https://docs.chargefy.io/payments/customer-portal): authenticate your customer before creating the session and return only the corresponding URL                                                            |

## Cancellation and synchronization

Distinguish immediate cancellation from cancellation at the end of the period;
confirm the intended behavior before writing the integration. Scheduling the end
does not revoke access at the time of the request. Canceling the agreement does
not refund previous payments. Use documented endpoints rather than writing
statuses yourself.

Synchronize `subscription.created`, `subscription.updated`,
`subscription.canceled`, `invoice.paid`, and `invoice.payment.failed` as needed
for the flow. Events are snapshots, may repeat, and may arrive out of order:
verify signatures, deduplicate, and fetch the current resource when necessary.
See the [event catalog](https://docs.chargefy.io/api-reference/events/types).

Test creation, failed and recovered renewals, trials without a card, pending
changes, and cancellation as relevant to the implemented flow. Use documented
[sandbox](https://docs.chargefy.io/api-reference/sandbox) cards. MCP can help with
queries; subscription and invoice mutations require the available public
endpoints, not invented tools. Skills do not authorize real charges.
