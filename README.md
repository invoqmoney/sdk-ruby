# invoq Ruby SDK

Accept stablecoin payments with invoq from Ruby server code. This SDK wraps
invoq server APIs and verifies signed webhooks.

Use this gem only on your server. It handles secret keys and should not be
bundled into browser code.

## Installation

Install the gem:

```sh
gem install invoq
```

Or add it to a Gemfile:

```ruby
gem "invoq"
```

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
timeout.

## Invoices

Create an invoice:

```ruby
invoice = invoq.invoices.create(
  amount: "129",
  currency: "USD",
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)
```

Notes:

- Use a server-side amount. Do not trust client-supplied amounts.
- `amount` is a decimal USD string from `"0.01"` to `"999.99"` with up to 2 decimal places.
- `currency` is optional and defaults to `"USD"`.
- Use `reference_id` to map `invoice.paid` webhooks back to your order.
  Creating again with the same `reference_id` and invoice terms returns the
  existing invoice; different terms fail with a `409 reference_id_conflict` API
  error.

Get an invoice:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` returns the public invoice shape used by hosted checkout. It
includes fields such as `amount_paid`, `amount_due`, `payment_status`,
`project`, `deposit_address`, `monitoring_ends_at`, and `direct_onchain_rails`,
but does not include `reference_id`. Use the create response or
`invoice.paid` webhook when you need your merchant `reference_id`.

Create a test payment:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

`create_test_payment` only works for invoices created with a `sk_test_` key.
Partial amounts are allowed and produce `partially_paid`; when payments reach
the invoice amount, invoq sends a signed `invoice.paid` webhook to your test
webhook URL.

Each invoice method returns the response `data` object directly as a Ruby hash.

## Inputs and responses

The SDK checks that `amount` values and `invoice_id` arguments are non-empty
strings before sending requests. The invoq API validates the amount format,
range, and currency.

Leave unset optional fields out of the request hash. When you include
`description` or `reference_id`, pass a string. `return_url` can be a string or
`nil`.

Amounts in responses are normalized to 4 decimal places: create with `"129"`
and the invoice returns `amount: "129.0000"`. Compare amounts numerically, not
as strings. `amount_due` is derived as `max(amount - amount_paid, 0)` and uses
the same 18-decimal scale as `amount_paid`.

## Webhooks

Pass the raw request body to `verify_webhook`. Do not parse JSON and encode it
again before verification.

```ruby
raw_body = request.body.read
event = Invoq.verify_webhook(
  raw_body,
  { "invoq-signature" => request.get_header("HTTP_INVOQ_SIGNATURE") },
  ENV.fetch("INVOQ_WEBHOOK_SECRET")
)

if Invoq.invoice_paid?(event)
  order_id = event.fetch("data").fetch("invoice").fetch("reference_id")
  raise "Missing reference_id" if order_id.nil?

  # Fulfill the order for order_id.
end
```

Use `invoice.paid` webhooks to fulfill orders on your server. Browser checkout
results are only for updating the customer experience; do not fulfill orders
from browser results.

Important:

- Pass the exact raw request body string received by your Ruby framework.
- Pass the `invoq-signature` header.
- Use your webhook secret (`whsec_...`), not your invoq API secret key.
- Make fulfillment idempotent. Failed webhook deliveries are retried, so the
  same event can arrive more than once.
- Respond with a 2xx quickly. Transient failures are retried.

`Invoq.invoice_paid?` accepts fulfillable `invoice.paid` events whose invoice
status is `paid`, `settling`, or `settled`; it rejects `review_required`.

Webhook verification failures raise `Invoq::SignatureVerificationError`.

## Errors

```ruby
begin
  invoq.invoices.create(amount: "0.001", currency: "USD")
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
