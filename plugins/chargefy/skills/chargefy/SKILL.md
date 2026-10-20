---
name: chargefy
description: Guide Chargefy integrations, configure credentials and environments, model organizations, customers, products, and prices, and apply API best practices. Use when starting a project, understanding concepts, choosing a flow, handling errors, or reviewing security and idempotency.
---

# Integrate with Chargefy

Use this skill to prepare an integration and understand the public model. It
does not grant account access. Preserve the partner's requested flow and scope.
Respond to the user in their preferred language.

## Choose a skill

| Topic                                                             | Skill                   |
| ----------------------------------------------------------------- | ----------------------- |
| First integration, credentials, modeling, conventions, and review | `chargefy` (this skill) |
| Checkout, payments, webhooks, and testing                         | `chargefy-payments`     |
| Subscriptions, invoices, trials, proration, and recovery          | `chargefy-billing`      |
| Connected organizations, activation, and branding                 | `chargefy-platforms`    |

Each skill works without MCP. If a specialized skill is not installed, consult
the relevant public guide in the map below rather than blocking the task.

## Find the contract before implementing

- Consult the [documentation index](https://docs.chargefy.io/llms.txt) and read only relevant pages. Pages are also available as Markdown by appending `.md` to the path.
- With MCP connected, use `search_chargefy_documentation` to find the guide and `chargefy_api_search` followed by `chargefy_api_details` to inspect contracts for available operations.
- Confirm field names, events, methods, and constraints in the current endpoint. Do not infer a request from a response object: some input fields have their own names.
- If an operation is unavailable through MCP, consult the [public API](https://docs.chargefy.io/api-reference/introduction). API availability does not imply that the agent can execute it through MCP.

## Prepare the project

Use the environment variable names already adopted by the project. To get started:

1. Obtain a test key in the dashboard under Developers → API keys. Use the smallest sufficient scope; `read` is enough for queries.
2. Store the key outside versioned code, in a Git-ignored file or secret manager. Keep values empty in `.env.example`. Do not ask for credentials in the conversation.
3. Validate with a read, without creating a charge:

```bash
curl -sS "https://api.chargefy.io/v1/customers?limit=1" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY"
```

An empty list with HTTP 200 is valid. For `401`, check for a missing, revoked, or
expired key; for `403`, check scope and organization; for `404`, also check the
environment. Test resources exposing `livemode` should return `false`. Do not
print the key to diagnose a problem.

MCP is optional. To connect the account, follow the
[agent guide](https://docs.chargefy.io/get-started/ai-agents); installing skills
does not connect the account or authorize operations on it.

## Essential relationships

| Object         | Responsibility                                                | Example                                    |
| -------------- | ------------------------------------------------------------- | ------------------------------------------ |
| Organization   | Account owning the catalog, customers, and payments           | The company selling the plan               |
| Customer       | Buyer within that organization                                | Ana, a customer of that company            |
| Product        | What is sold                                                  | Pro plan                                   |
| Price          | Amount, currency, and commercial terms for a product          | BRL 99 per month or BRL 990 per year       |
| Subscription   | Recurring agreement for a customer, with items and quantities | Ana subscribes to monthly Pro with 3 seats |
| Invoice        | Bill with items, amounts, and status; one-time or recurring   | September's cycle invoice                  |
| Payment Intent | Tracks a payment and its outcome                              | Payment for September's invoice            |
| Charge         | Records a charge attempt                                      | First attempt declined, second approved    |
| Transaction    | Records financial movements for reconciliation                | Credit or debit associated with a sale     |

A product can have multiple prices. A subscription can have multiple items, but
they must share the same currency and cadence. The same person can be a customer
of different organizations; do not reuse IDs across accounts.

Read about [products and prices](https://docs.chargefy.io/products-prices-discounts/manage-products-and-prices),
[customers](https://docs.chargefy.io/payments/customers),
[payments and charges](https://docs.chargefy.io/payments/payments-vs-charges), and
[payments and transactions](https://docs.chargefy.io/payments/payments-vs-transactions)
for each resource's boundaries.

## Choose the model

- Reusable offer: Product + Price. The product describes what is sold; the price defines how to charge. A name such as "Monthly Pro" alone does not configure recurrence.
- Negotiated amount for one purchase: use `price_data` only in a flow whose schema supports it. Do not turn every purchase into a new product by default.
- Change in amount or billing cadence: create another Price and explicitly decide what happens to existing agreements. Changing the catalog does not migrate all subscriptions.
- Offer shared by URL: a Payment Link can generate multiple sessions. A Checkout Session represents a purchase experience with its own expiration; it is neither a subscription nor a permanent link.
- Recurrence: Subscription coordinates the cycle and generates an Invoice. Do not implement a separate scheduler that charges the same cycle again.
- Save a card: a Setup Intent prepares a Payment Method; it is not a payment. Chargefy.js collects the card in the browser using a publishable key.
- Discounts: use public discount and coupon resources; external correlation can go in `metadata`, but it does not replace a business field.

Example: "I want to sell Pro for BRL 99/month." In the selling organization,
find or create Product Pro, create a recurring Price of `9900` cents in `brl`,
identify Customer Ana, and use the chosen subscription flow. Each cycle has an
Invoice; a card failure does not create another Customer or Product.

## Keep statuses distinct

`checkout.session.completed` means the session completed; asynchronous methods
may settle later. An approved payment does not mean money has already reached a
bank account. A `trialing` subscription can grant access without a payment;
`incomplete` is waiting for the first payment. Separate commercial, payment, and
reconciliation states in your system.

Consult the [payment lifecycle](https://docs.chargefy.io/integrate/payment-lifecycle),
[subscriptions](https://docs.chargefy.io/payments/subscriptions), and
[invoices](https://docs.chargefy.io/payments/invoices) before defining transitions.
Read the current endpoint when writing requests: relationship names in responses
do not guarantee the same names in inputs.

## API best practices

### Authenticate

```bash
curl "https://api.chargefy.io/v1/customers?limit=1" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY"
```

`X-Chargefy-Api-Key` is an alternative when a proxy already reserves
`Authorization` (if both are sent, `X-Chargefy-Api-Key` takes precedence).

| Prefix     | Meaning         | Where it may appear |
| ---------- | --------------- | ------------------- |
| `ch_live_` | Live secret key | Backend only        |
| `ch_test_` | Test secret key | Backend only        |
| `pk_`      | Publishable key | Browser             |

A secret key in a browser or client app is a leak; supported browser flows use
the publishable key. Scopes are hierarchical: `read` ⊂ `write` ⊂ `admin`;
use the smallest sufficient scope.

### Errors

```json
{
  "error": {
    "code": "parameter_missing",
    "doc_url": "https://docs.chargefy.io/api-reference/errors",
    "message": "Missing required param: amount.",
    "param": "amount",
    "type": "invalid_request_error"
  }
}
```

Branch on `error.code`; `error.message` is English and can change, so use it for
logs and support. `error.type` distinguishes families: `invalid_request_error`,
`authentication_error`, `card_error`, `rate_limit_error`, and `api_error`.

Every response includes `X-Request-Id`; record it together with the status and
`code` for support.

#### What can be retried

| Status                            | Retry?                                                                    |
| --------------------------------- | ------------------------------------------------------------------------- |
| `400`, `401`, `403`, `404`, `422` | No. Fix the request, credentials, or data.                                |
| `402`                             | Not without buyer action (card declined).                                 |
| `409`                             | Depends on the `code`; generally resolve the state first.                 |
| `429`                             | Yes, after the `Retry-After` seconds, with backoff and jitter.            |
| `500`                             | Yes, with exponential backoff and jitter.                                 |
| `502 payment_result_unconfirmed`  | **Do not repeat the write.** Query the resource and wait for the webhook. |

That last case prevents double charging: the attempt may have reached processing
even though its response did not return.

#### Rate limits

Each API key has per-minute quotas: 120 reads, 120 writes and 40 calls in any
10 seconds (platform keys with the `Organization` header: 1,800, 720 and 450).
A call over the quota returns `429 rate_limit_exceeded` with `Retry-After` and
is not processed. Wait for a Pix or any asynchronous payment
through webhooks instead of polling, and sync by date range with list endpoints
(`created_at[gte]`, `limit=100`, `starting_after`) instead of fetching item by
item. See [rate limits](https://docs.chargefy.io/api-reference/rate-limits).

### Idempotency

Send `Idempotency-Key` with any `POST` or `DELETE` that changes state. The header
is always optional and has no body equivalent.

- The first call executes and stores the response.
- Repeating the **same key and body** returns the stored response with `Idempotent-Replayed: true`.
- A key is unique per organization **and environment**; the same string in test and live represents different keys.
- It expires 24 hours after the operation completes. Maximum length is 255 characters.
- Same key with a different body → `400 idempotency_key_reused`. Previous request still running → `409 idempotency_key_in_progress`.
- `5xx`, `409`, `425`, and `429` do not become final results: the key remains usable and a retry executes again.

Use a unique value per logical operation, including the resource and action; for
example, `order-8f4c2a-create-checkout`. During imports, also map local IDs to
Chargefy IDs: 24-hour idempotency does not prevent duplicates forever.

### Pagination

Use cursors, never page numbers. All list endpoints share this envelope:

```json
{ "object": "list", "data": [], "has_more": false, "url": "/v1/customers" }
```

`limit` accepts 1–100 (default 10). Move forward with `starting_after` set to the
**last** item's ID; move backward with `ending_before` set to the **first** item's
ID. Use only one cursor per request. Stop when `has_more` is `false`, and preserve
the same filters across pages; only the cursor changes.

### Money

Amounts are integers in the currency's smallest unit. For `brl`, that means
cents: `19990` is BRL 199.90. Fields ending in `_amount` follow this rule;
fields ending in `_rate` are percentages in basis points, so `fee_amount: 399`
is BRL 3.99 while `fee_rate: 399` is 3.99%.

Convert once at the input boundary and keep integers afterward; floating-point
money calculations introduce cent discrepancies. Currency codes use lowercase
ISO 4217 values.

### Dates

Instants require an explicit time zone: `2026-08-10T12:00:00Z` or an offset such
as `-03:00`. Without a time zone, the API returns `400`. A date alone
(`2026-08-10`) is not an instant. For due dates, use `days_until_due` when the
endpoint offers it; if the contract requires an instant, specify the intended
time and time zone.

The dashboard's configured time zone does **not** affect billing: it changes how
dates are displayed, not when a cycle changes.

### IDs and references

Every public ID has a prefix (`cus_`, `price_`, `sub_`, `inv_`, `pi_`, `ch_`,
`evt_`, `cs_`, `pm_`, `seti_`, `re_`, `dp_`). Watch out for `ch_`: it prefixes
**charges** and also starts secret keys `ch_live_` / `ch_test_`; a charge ID never
has `live_` or `test_` after its prefix.

In response objects, references use the resource name without an `_id` suffix:
`"customer": "cus_..."`, `"price": "price_..."`. In requests, some fields have
their own names, such as `price_id` inside `line_items`; confirm the endpoint
rather than inferring them.

Payment Intents and Charges also return an immutable human-readable `number`:
a payment may be `J9N6R8`, with attempts `J9N6R8-001` and `J9N6R8-002`.
Chargefy assigns these numbers automatically; do not send them as input.
Use them in screens and support conversations; keep `id` for API paths, cursors,
and resource relationships. See [payment references](https://docs.chargefy.io/payments/payments-vs-charges)
for the numbering rules and retry example.

Business rules do not belong in `metadata`. Use `metadata` to correlate records
with your system, not to store state that determines behavior.

### Confirm before writing code

Read the endpoint in the [public reference](https://docs.chargefy.io/api-reference/introduction).
If MCP is available, `chargefy_api_search` finds the operation and
`chargefy_api_details` returns its schema. Neither is required to use the skill.

### Review an integration

- Confirm outcomes through the current resource and signed events; redirects do not prove payment. Store events durably before returning `2xx`, deduplicate by `event.id`, and tolerate out-of-order delivery.
- Preserve organization and environment across every relationship. A price from another organization cannot be used in this account's checkout.
- Avoid logging keys, `client_secret`, bodies containing personal data, card data, or webhook signatures. Record the public ID and request ID needed for support.
- Build requests from the endpoint schema. Checkout `mode` is computed; response references do not guarantee matching input names.
- For a requested review, report the file/line, failure scenario, and fix. For example, resending the same purchase with a different key may create two charges. Do not modify real resources to demonstrate the issue.

Consult [idempotency](https://docs.chargefy.io/api-reference/idempotency),
[errors](https://docs.chargefy.io/api-reference/errors), and the
[go-live checklist](https://docs.chargefy.io/go-live-checklist) when preparing for production.

## Integration map

Choose the path by the requested outcome and read both the guide **and** the
relevant endpoint before writing payloads. These references cover the public
domains; the [complete index](https://docs.chargefy.io/llms.txt) includes other
guides, and API reference navigation lists each resource's operations. Do not
load the entire documentation for a narrow task.

### Sell and collect payments

| Partner request                                                     | References and decision                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prepare the account, environment, and credentials                   | [First payment](https://docs.chargefy.io/accept-your-first-payment), [keys](https://docs.chargefy.io/api-reference/api-keys), and [authentication](https://docs.chargefy.io/api-reference/authentication).                                                                                                                                                                                                                   |
| Choose a link, hosted page, or custom interface                     | [Choose an integration](https://docs.chargefy.io/choose-an-integration). Preserve the user's requested experience.                                                                                                                                                                                                                                                                                                           |
| Create a catalog, one-time/recurring prices, discounts, and coupons | [Products and prices](https://docs.chargefy.io/products-prices-discounts/manage-products-and-prices) and [discounts](https://docs.chargefy.io/products-prices-discounts/create-and-apply-discounts).                                                                                                                                                                                                                         |
| Share a reusable offer                                              | [Payment Link](https://docs.chargefy.io/payments/create-payment-link) and [API creation](https://docs.chargefy.io/api-reference/payment-links/create).                                                                                                                                                                                                                                                                       |
| Generate a payment page for each purchase                           | [Hosted checkout](https://docs.chargefy.io/payments/create-hosted-checkout-page) and [create a Checkout Session](https://docs.chargefy.io/api-reference/checkout-sessions/create).                                                                                                                                                                                                                                           |
| Customize the page, brand, domain, fields, and additional offers    | [Configure checkout](https://docs.chargefy.io/payments/configure-checkout-page), [brand and appearance](https://docs.chargefy.io/payments/brand-and-appearance), [data collection](https://docs.chargefy.io/payments/collect-buyer-data), [domain](https://docs.chargefy.io/payments/custom-domain), and the link/session creation contract for `optional_items`.                                                            |
| Charge a card or Pix directly                                       | [Create a payment](https://docs.chargefy.io/payments/create-payment) and [Payment Intent](https://docs.chargefy.io/api-reference/payment-intents/object).                                                                                                                                                                                                                                                                    |
| Offer boleto                                                        | [Boleto](https://docs.chargefy.io/payments/boleto) and [methods by flow](https://docs.chargefy.io/payments/payment-methods). Do not assume direct Payment Intent creation supports it.                                                                                                                                                                                                                                       |
| Build a custom interface or save a card                             | [White-label checkout](https://docs.chargefy.io/payments/build-white-label-checkout), [Chargefy.js](https://docs.chargefy.io/api/chargefy-js), [save a card](https://docs.chargefy.io/payments/save-card-for-later), and [customers](https://docs.chargefy.io/payments/customers).                                                                                                                                           |
| Show installments or pass fees to buyers                            | [Payment preview](https://docs.chargefy.io/api-reference/payment-previews/create) and [buyer-paid fees](https://docs.chargefy.io/payments/pass-fees-to-buyer). A preview does not charge.                                                                                                                                                                                                                                    |
| Capture later, cancel an attempt, or renew a payment code           | [Capture](https://docs.chargefy.io/payments/asynchronous-capture), [cancellation](https://docs.chargefy.io/payments/cancel-payment-attempt), [regenerate Pix](https://docs.chargefy.io/api-reference/payment-intents/regenerate-pix), and [boleto](https://docs.chargefy.io/api-reference/payment-intents/regenerate-boleto).                                                                                                |
| Offer an upsell, track campaigns, or grant access                   | [Funnels](https://docs.chargefy.io/payments/create-upsell-funnel), [tracking](https://docs.chargefy.io/payments/marketing-tracking), [UTMs through the API](https://docs.chargefy.io/payments/create-checkout-session-with-utms), [Meta pixel](https://docs.chargefy.io/payments/configure-meta-pixel), and [Cademí](https://docs.chargefy.io/payments/integrate-cademi). Not every dashboard setting has a public endpoint. |

### Billing and self-service

| Partner request                                                                     | References and decision                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Create a subscription, trial, or annual plan paid in installments                   | [Subscriptions](https://docs.chargefy.io/payments/create-subscriptions), [trial](https://docs.chargefy.io/payments/subscription-trial), and [installment subscriptions](https://docs.chargefy.io/payments/sell-subscriptions-in-installments).                                                                                                                                                                                               |
| Change a plan, items, or quantity with proration                                    | [Updates](https://docs.chargefy.io/payments/update-subscriptions-with-proration), [items](https://docs.chargefy.io/api-reference/subscription-items/create), and [invoice preview](https://docs.chargefy.io/api-reference/invoice-previews/create). A preview does not change the subscription.                                                                                                                                              |
| Schedule phases or charge for usage                                                 | [Schedules](https://docs.chargefy.io/api-reference/subscription-schedules/create) and [usage records](https://docs.chargefy.io/api-reference/subscription-item-usage-records/create).                                                                                                                                                                                                                                                        |
| Activate an incomplete subscription, recover overdue payments, or end the agreement | [Pending first payment](https://docs.chargefy.io/payments/activate-incomplete-subscriptions), [recovery](https://docs.chargefy.io/payments/revenue-recovery), [update](https://docs.chargefy.io/api-reference/subscriptions/update), [cancellation](https://docs.chargefy.io/api-reference/subscriptions/delete), and [resume](https://docs.chargefy.io/api-reference/subscriptions/resume). Check statuses and effects on the next payment. |
| Issue, send, pay, or void an invoice                                                | [Invoices](https://docs.chargefy.io/payments/invoices) and [invoices API](https://docs.chargefy.io/api-reference/invoices/object).                                                                                                                                                                                                                                                                                                           |
| Let customers manage their cards, subscriptions, and invoices                       | [Customer portal](https://docs.chargefy.io/payments/customer-portal) and [portal session](https://docs.chargefy.io/api-reference/customer-portal-sessions/create). The URL is temporary.                                                                                                                                                                                                                                                     |
| Migrate customers, catalogs, or recurring agreements                                | [Migration](https://docs.chargefy.io/migrate) and [subscription imports](https://docs.chargefy.io/payments/import-subscriptions). Preserve the paid period and next billing date according to the import contract.                                                                                                                                                                                                                           |

### Platforms and operations

| Partner request                                                  | References and decision                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Create and operate connected organizations                       | [Platforms](https://docs.chargefy.io/platforms/overview) and [connected organizations](https://docs.chargefy.io/platforms/connected-organizations).                                                                                                                                                                                                                                                                                                                                                                                        |
| Activate an account, collect documents, and resolve requirements | [Hosted activation](https://docs.chargefy.io/platforms/activate-organization-with-hosted-session), [API activation](https://docs.chargefy.io/platforms/activate-organization-by-api), [rejections](https://docs.chargefy.io/platforms/resolve-activation-rejections), [resubmission](https://docs.chargefy.io/platforms/resubmit-organization-verification), and [files](https://docs.chargefy.io/api-reference/files/create). A `kyc_document` uploaded through the API expires 30 days after upload unless referenced in `verification`. |
| Use the platform's brand and domain                              | [Platform branding and domain](https://docs.chargefy.io/platforms/branding-and-custom-domain) and [brand and appearance](https://docs.chargefy.io/payments/brand-and-appearance). The resource's owning organization and branding origin are different concepts. A child's `branding_settings.appearance` is sent complete or `null` to inherit the platform's.                                                                                                                                                                            |
| Register a bank account or understand balance and settlement     | [Bank accounts](https://docs.chargefy.io/api-reference/payout-accounts/create), [financial model](https://docs.chargefy.io/business-model/introduction), [fees](https://docs.chargefy.io/business-model/fees), and [reconciliation](https://docs.chargefy.io/payments/reconcile-payments). Direct payout-account registration does not work in sandbox; distinguish it from the simulated account created during activation.                                                                                                               |
| Refund in full/part or respond to a dispute                      | [Refund](https://docs.chargefy.io/payments/refund-payment), [refund contract](https://docs.chargefy.io/api-reference/refunds/create), and [disputes](https://docs.chargefy.io/payments/respond-to-disputes). Check eligibility, deadlines, and final status.                                                                                                                                                                                                                                                                               |
| Confirm a sale, reconcile, or investigate a failure              | [Order fulfillment](https://docs.chargefy.io/payments/fulfill-orders), [reconciliation](https://docs.chargefy.io/payments/reconcile-payments), [transactions](https://docs.chargefy.io/api-reference/transactions/object), [requests](https://docs.chargefy.io/api-reference/requests/list), and [failure codes](https://docs.chargefy.io/api-reference/charges/failure-codes).                                                                                                                                                            |
| Receive events and track deliveries                              | [Choose events](https://docs.chargefy.io/integrate/webhooks/events), [delivery](https://docs.chargefy.io/integrate/webhooks/delivery), [endpoints](https://docs.chargefy.io/api-reference/webhook-endpoints/create), and [event catalog](https://docs.chargefy.io/api-reference/events/types).                                                                                                                                                                                                                                             |
| Check commercial eligibility or supported countries              | [Coverage](https://docs.chargefy.io/business-model/supported-countries) and [acceptable use](https://docs.chargefy.io/business-model/acceptable-use). Do not infer support from similarities to another service.                                                                                                                                                                                                                                                                                                                           |

## Coverage limits

This skill covers public integrations, not internal dashboard endpoints. If a
capability has no documented public contract, such as arbitrary splits among
multiple recipients, early settlement, or antifraud configuration, do not invent
payloads or import another provider's behavior. State what you found and what
needs confirmation. Distinguish documented capabilities, observed test results,
and production restrictions.

## Test the integration

Use the [sandbox](https://docs.chargefy.io/test-payments-in-sandbox) to check
approval, decline, and asynchronous outcomes relevant to the flow. Consult
documented cards and scenarios rather than inventing numbers. Also validate
duplicate events and repeated requests when implementing webhooks or retries.
Before going live, consult the
[go-live checklist](https://docs.chargefy.io/go-live-checklist).

## When to access the account through MCP

Server: `https://mcp.chargefy.io`. The [agent guide](https://docs.chargefy.io/get-started/ai-agents)
explains installation in Claude Code, Codex, and Cursor.

Start with `get_chargefy_account_info` to identify the organization, environments,
and permissions. Discover an operation and its schema before executing it. For
data access, explicitly select `livemode: false` for testing or `livemode: true`
when the request involves production.

MCP provides queries and creation/editing of customers, catalogs, discounts, and
payment links according to permissions. It does not execute capture, refunds,
subscription cancellation, or key/webhook management. Respect the request and
connection scope; installing this skill does not authorize new account actions.
See [tools](https://docs.chargefy.io/mcp/tools) and
[limits](https://docs.chargefy.io/mcp/limits) for current details.
