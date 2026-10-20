---
name: chargefy-platforms
description: Integrate Chargefy for Platforms with connected organizations, hosted or API activation, per-account catalogs, credentials, branding, and webhooks. Use when onboarding participants or operating payments in the correct organization scope.
---

# Platforms and connected organizations

A platform creates and operates connected organizations. A participant's public
identifier is `org_*`. Each organization owns its catalog, customers, and
payments; a platform does not make prices or customers shared across accounts.
Respond to the user in their preferred language.

## Credentials and scope

| Operation                                     | How to select the organization                                                                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Create/list organizations                     | Platform API key, without the `Organization` header                                                                                            |
| Retrieve/update/submit an organization        | ID in the endpoint URL; no `Organization` header                                                                                               |
| Operate resources of a connected organization | Platform API key + `Organization` header where the endpoint accepts it                                                                         |
| Register webhook endpoints                    | Platform API key + `Organization` header; for the connected organizations' events (`events_from: "platform"`), the platform's own organization |
| Use an organization API key                   | That account only; do not send `Organization`                                                                                                  |
| Identify the source of a webhook              | Top-level `organization` field, after verifying the signature                                                                                  |

The platform's own organization is also a connected organization: it is listed,
can be read, and its profile, brand and metadata can be updated. Its
registration, fee plan, submission and deletion are not changed through the API.
A connected organization never becomes a platform.

Do not use middleware that indiscriminately adds this header to every request.
Read about [connected organizations](https://docs.chargefy.io/platforms/connected-organizations)
and [authentication](https://docs.chargefy.io/api-reference/authentication).

## Register and activate

1. Create the organization with its tax identity and store the returned `id`. Repeated creation with the same tax document within the platform returns the same organization.
2. Choose [hosted activation](https://docs.chargefy.io/platforms/activate-organization-with-hosted-session) or [API activation](https://docs.chargefy.io/platforms/activate-organization-by-api) based on the requested product. Both update the same public registration.
3. In the hosted flow, create the Activation Session when you are ready to redirect. The initial URL expires in 60 seconds; request another for the same organization if it expires. Returning to your site does not prove approval.
4. In the API flow, check `requirements.missing`, `pending_verification`, and `errors`, send the required fields/documents, and submit for review. A saved registration has not necessarily been submitted or approved.
5. Track `organization.updated` and fetch the current state. For registration reviews, also use `organization.review.required` and `organization.review.submitted`.

For files, use the [files API](https://docs.chargefy.io/api-reference/files/create)
and the purpose documented for the flow. A `kyc_document` uploaded through the
API waits 30 days to be referenced in the `verification` block (`expires_at`
on the file); after that the update answers `400 file_expired` and the file
must be uploaded again. Referencing it clears the expiry; nothing is ever
deleted. Do not use internal storage URLs or log document contents. For corrections or rejections, follow
[resolve rejections](https://docs.chargefy.io/platforms/resolve-activation-rejections)
and [resubmit registration](https://docs.chargefy.io/platforms/resubmit-organization-verification).

## Sell through the organization

Example: a course platform onboards School A and sells its course for BRL 99.
Create the Product and Price in School A, then a Checkout Session using the Price
from that same account. In the backend, use the platform key and School A's
`Organization` header. Do not reuse a Price from School B.

- The platform origin and its configuration determine [branding and domain](https://docs.chargefy.io/platforms/branding-and-custom-domain); replacing a local image does not configure that origin.
- A child organization's look is `branding_settings.appearance` on `POST /v1/organizations/{id}`: send all seven keys (button and background colors as a catalog name, hex `#RRGGBB` or `null`) or `null` to inherit the platform's. Reads show only what was saved. See [brand and appearance](https://docs.chargefy.io/payments/brand-and-appearance).
- In a custom checkout, the browser uses the platform's publishable key and the `client_secret` issued in the correct scope, in the same environment. It sends neither `Organization` nor a secret key. Read the [white-label guide](https://docs.chargefy.io/payments/build-white-label-checkout).
- Preserve the organization relationship in your database and event reconciliation. An ID received from the browser is not sufficient to authorize access to an account.
- For reconciliation and platform fees, consult the public contract for the chosen flow. Do not infer bank settlement from an approved payment or invent arbitrary splits between recipients.

## MCP and public limits

MCP uses the organization, environments, and permissions authorized for the
connection. Its `organization` argument neither replaces the HTTP header nor
grants access to another account. A connection for the platform's owning
organization can query children through the available operations; this does not
authorize creating their catalogs. MCP does not accept platform API keys.
See [usage](https://docs.chargefy.io/mcp/how-to-use) and
[tools](https://docs.chargefy.io/mcp/tools).

Use only documented public capabilities. Do not expose internal financial
registration details or dashboard endpoints as partner contracts. Start
validation in test mode and confirm scope before any requested mutation.
