# invoq Ruby SDK

**English** · [Bahasa Indonesia](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.id.md) · [Español](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.es-419.md) · [Français](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.fr.md) · [Português](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.pt-BR.md) · [Tiếng Việt](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.vi.md) · [Türkçe](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.tr.md) · [ไทย](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.th.md) · [简体中文](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.zh-Hans.md) · [繁體中文](https://github.com/invoqmoney/sdk-ruby/blob/main/docs/README.zh-Hant.md)

Accept stablecoin payments with invoq from Ruby server code. This SDK wraps
invoq server APIs and verifies signed webhooks.

Use this gem only on your server. It handles secret keys and should not be
bundled into browser code.

**Coding with AI? Paste this.**

```
Add stablecoin payments to my project with invoq. Start in test mode. Read the docs before you write any code: https://invoq.money/llms.txt
```

## Server SDKs

Create invoices and verify webhooks from your backend in any of these languages — same REST API, same webhook signature. This repository is the Ruby SDK.

| Language | Repository |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **this repo** |

The browser side is the same for every backend: **`@invoq/checkout`** (JavaScript, in [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) opens the in-page checkout modal for any frontend.

## Installation

Install the gem:

```sh
gem install invoq
```

Or add it to a Gemfile:

```ruby
gem "invoq"
```

Requires Ruby 2.6 or newer.

## Get your keys

1. Sign in to the [invoq dashboard](https://app.invoq.money) and create a
   project.
2. On the **API keys** page, create a secret key. Test keys start with
   `sk_test_`, live keys with `sk_live_`. The key mode determines whether
   invoices are test or live.
3. In your project's **webhooks** settings, save your webhook URL. The webhook
   secret (`whsec_...`) for that mode is shown once, when you first enable the
   webhook. Store it right away. Webhook URLs must be public HTTPS URLs.
4. Set up your **Receiving wallet** before going live. Test invoices don't need
   one; a live invoice with nowhere to settle fails with
   `409 no_payment_options_available`.

Add both to your server environment:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Start with test keys. Switch to the live key and live webhook secret when you
go to production.

## Create a client

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Default production API origin:

```txt
https://api.invoq.money
```

Override the API origin and request timeout during development:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` must be an absolute `http` or `https` origin with no path, query,
hash, username, or password. The SDK appends `/v1/...` resource paths.

Requests time out after 10 seconds by default. Pass `timeout_ms` to change the
timeout. `timeout_ms` must be a positive integer in milliseconds.

## Invoices

Create an invoice:

```ruby
invoice = invoq.invoices.create(
  amount: "129",
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)

invoice_id = invoice.fetch("id")
checkout_url = "https://pay.invoq.money/#{invoice_id}"
```

Notes:

- Use a server-side amount. Do not trust client-supplied amounts.
- `amount` is a decimal USD string from `"0.01"` to `"1000000.00"` with up
  to 2 decimal places, such as `"129"` or `"129.99"`. Currency is always USD,
  and test or live comes from the key — neither is a request field.
- Use a stable, non-empty `reference_id` to map `invoice.paid` webhooks back to
  your order. Creating again with the same `reference_id` and invoice terms
  returns the existing invoice; different terms fail with a
  `409 reference_id_conflict` API error.
- If you fulfill by invoice ID instead of `reference_id`, store `invoice_id`
  with your order when you create the invoice.
- Omit `return_url` to use the project's default return URL. Pass `nil` to send
  JSON `null` and create the invoice without a return URL. On `reference_id`
  retries, pass `return_url` explicitly when you need to assert a specific
  value.
- `description` and `reference_id` must be strings when present.

Get an invoice:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` returns the public invoice shape used by hosted checkout: the
create shape plus `amount_paid`, `project`, and `transfers`, minus
`reference_id`. Use the create response or the `invoice.paid` webhook when you
need your merchant `reference_id`.

Create a test payment:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Test invoices cannot receive real funds. Simulate payments from your server
instead.

`create_test_payment` only works for invoices created with a `sk_test_` key.
Partial amounts are allowed and produce `partially_paid`; when payments reach
the invoice amount, invoq sends a signed `invoice.paid` webhook to your test
webhook URL.

`reference_id` is optional for test payments. Omit it when unset; do not pass
`nil`.

To receive webhooks on your machine, expose your local server with an HTTPS
tunnel such as ngrok or cloudflared and save the tunnel URL as your test webhook
URL in the dashboard.

Each invoice method returns the response `data` object directly as a Ruby hash.

## Hosted checkout page

Every invoice also has a hosted checkout page at:

```txt
https://pay.invoq.money/<invoice id>
```

Share the link or redirect to it when an in-page checkout modal is not a fit.

## Inputs and responses

The SDK checks that `amount` values and `invoice_id` arguments are non-empty
strings before sending requests. The invoq API validates the amount format and
range.

Leave unset optional fields out of the request hash. When you include
`description` or `reference_id`, pass a string. `return_url` can be a string or
`nil`. Any other key in the hash is dropped rather than sent, because the API
rejects unknown body keys.

Amounts in responses are normalized to 4 decimal places: create with `"129"`
and the invoice returns `amount: "129.0000"`. Compare amounts numerically, not
as strings. `amount_due` is derived as `max(amount - amount_paid, 0)` and uses
the same 18-decimal scale as `amount_paid`; `amount_overpaid` is its mirror,
`max(amount_paid - amount, 0)`, so you never subtract money yourself.

Two status fields. `status` is the accounting one — `unpaid`, `partially_paid`,
`paid`, `settling`, `settled`, `review_required` — where the three paid-like
values differ only in how far the funds have moved to your wallet.
`checkout_status` is payer-facing — `open`, `confirming`, `expired`, `paid`,
`unavailable` — and never authorizes fulfillment. `payment_revision` is a
non-negative integer that increments whenever the confirmed payment set changes,
so you can discard a snapshot older than one you already hold.

`payment_options` holds the payment instructions, fixed at creation and `[]` in
test mode. Entries are discriminated by `status`, then `collection_method`: only
`"ready"` is payable, `"evm_deposit"` carries `deposit_address` and
`suggested_amount`, `"direct_exact"` carries `recipient_address` and an
`exact_amount` the buyer must send to the digit. `transfers` is the confirmed
receipt trail — `transaction_id`, `event_index`, `amount`,
`explorer_transaction_url` — and stays `[]` until a payment confirms. Full field
reference: [REST API docs](https://github.com/invoqmoney/api).

Identify a payment option by `chain_namespace`, `chain_reference`, and
`token_address`, never by its position in the array. `monitoring_ends_at` is the
end of the payment window, and is `nil` for test invoices.

## Webhooks

Pass the raw request body to `verify_webhook`. Do not parse JSON and encode it
again before verification.

This Rack example returns `[status, headers, body]`. In Rails, use
`request.raw_post` and `request.get_header("HTTP_INVOQ_SIGNATURE")`; in Sinatra
or another Ruby framework, use the framework's raw request body and exposed
`invoq-signature` or `HTTP_INVOQ_SIGNATURE` header.

```ruby
def handle_invoq_webhook(env)
  raw_body = env.fetch("rack.input").read

  begin
    event = Invoq.verify_webhook(
      raw_body,
      { "invoq-signature" => env["HTTP_INVOQ_SIGNATURE"] },
      ENV.fetch("INVOQ_WEBHOOK_SECRET")
    )
  rescue Invoq::SignatureVerificationError
    return [
      400,
      { "content-type" => "application/json" },
      ['{"error":"invalid signature"}']
    ]
  end

  if Invoq.invoice_paid?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # Fulfill the order for fulfillment_key idempotently.
  elsif Invoq.invoice_payment_reversed?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # Hold or reverse the order for fulfillment_key.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Use `invoice.paid` webhooks to fulfill orders on your server. Browser checkout
results are only for updating the customer experience; do not fulfill orders
from browser results.

When `Invoq.invoice_paid?(event)` is true, the invoice is ready for automatic
fulfillment; use the invoice `reference_id` or a stored invoice `id` to find
and fulfill your order. A `review_required` invoice emits no `invoice.paid`
until the review clears. If checkout reports `review_required`, show a
pending-review state and wait for a later `invoice.paid` webhook after review
is approved.

invoq also sends `invoice.payment_reversed` when a previously paid invoice drops
back below its amount — a chain reorg dropping a confirmed transfer, for
example. Catch it with `Invoq.invoice_payment_reversed?(event)` and hold or
reverse the fulfillment according to your own policy.

Important:

- Pass the exact raw request body string received by your Ruby framework.
- Pass the `invoq-signature` header.
- `verify_webhook` does not require `Invoq.new(...)` or your invoq API secret
  key.
- Use your webhook secret (`whsec_...`), not `INVOQ_SECRET_KEY`.
- Make fulfillment idempotent. Retried webhook deliveries can send the same
  event more than once.
- Respond with a 2xx quickly. Any other status counts as a failed delivery and
  is retried, including redirects and `4xx`, so a deploy window or a temporarily
  misrouted path is retried rather than dropped. The ladder is 1 minute,
  5 minutes, 30 minutes, then 2 hours, for 5 attempts in total.
- Deliveries can arrive out of order. Keep the snapshot with the highest
  `payment_revision`.

`Invoq.invoice_paid?` accepts fulfillable `invoice.paid` events whose invoice
status is `paid`, `settling`, or `settled`; it rejects `review_required`.
`Invoq.invoice_payment_reversed?` accepts `invoice.payment_reversed` events
without checking the status at all: a reversal you drop leaves an order
fulfilled on a payment that no longer exists. An event type this SDK version
does not model still verifies and is returned as-is.

Webhook verification failures raise `Invoq::SignatureVerificationError`. The
SDK allows a 5-minute timestamp tolerance. The signature header is:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Errors

```ruby
begin
  invoq.invoices.create(amount: "0.001")
rescue Invoq::ApiError => error
  warn error.status
  warn error.code
  warn error.fields
  warn error.meta
  warn error.payload
rescue Invoq::Error
  raise
end
```

Non-2xx API responses raise `Invoq::ApiError` with `status`, `code`, `fields`,
`meta`, and the raw `payload`.

Connection failures, timeouts, invalid input, and response parse failures raise
`Invoq::Error`. Timed-out invoice creation is safe to retry with the same
`reference_id`.

Webhook verification failures raise `Invoq::SignatureVerificationError` with one
of these codes:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Development

```sh
bundle exec rake test
```

## License

Licensed under the MIT license.
