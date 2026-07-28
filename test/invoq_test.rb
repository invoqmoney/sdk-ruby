# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "openssl"

require "invoq"
require "invoq/internal/request"

class InvoqTest < Minitest::Test
  # Test mode: no payment window, no issued routes.
  INVOICE = {
    "id" => "inv_test_123",
    "mode" => "test",
    "amount" => "149.0000",
    "currency" => "USD",
    "reference_id" => "order_123",
    "description" => "Test order",
    "return_url" => "https://merchant.test/thanks",
    "status" => "unpaid",
    "checkout_status" => "unavailable",
    "payment_revision" => 0,
    "amount_due" => "149.000000000000000000",
    "amount_overpaid" => "0.000000000000000000",
    "monitoring_ends_at" => nil,
    "payment_options" => []
  }.freeze

  # The public read, carrying both collection methods and both option statuses.
  PUBLIC_INVOICE = {
    "id" => "inv_live_123",
    "mode" => "live",
    "amount" => "149.0000",
    "currency" => "USD",
    "description" => "Test order",
    "return_url" => nil,
    "project" => {
      "id" => "proj_test_123",
      "name" => "Test project",
      "logo_url" => nil
    },
    "status" => "unpaid",
    "checkout_status" => "open",
    "payment_revision" => 0,
    "amount_paid" => "0.000000000000000000",
    "amount_due" => "149.000000000000000000",
    "amount_overpaid" => "0.000000000000000000",
    "transfers" => [],
    "monitoring_ends_at" => "2026-06-16T00:00:00.000Z",
    "payment_options" => [
      {
        "collection_method" => "evm_deposit",
        "chain_namespace" => "eip155",
        "chain_reference" => "8453",
        "currency" => "USD",
        "token_address" => "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
        "token_decimals" => 6,
        "network_label" => "Base",
        "display_symbol" => "USDC",
        "logo_url" => nil,
        "chain_logo_url" => nil,
        "status" => "ready",
        "deposit_address" => "0x20c124f3919bb502c6126cda5bd6e5287859d5ca",
        "suggested_amount" => "149.000000"
      },
      {
        "collection_method" => "direct_exact",
        "chain_namespace" => "solana",
        "chain_reference" => "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
        "currency" => "USD",
        "token_address" => "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "token_decimals" => 6,
        "network_label" => "Solana",
        "display_symbol" => "USDC",
        "logo_url" => nil,
        "chain_logo_url" => nil,
        "status" => "ready",
        "recipient_address" => "GmaDrppBC7P5ARKV8g3djiwP89vz1jLK23V2GBjuAEGB",
        "invoice_amount" => "149.000000",
        "matching_increment" => "0.000123",
        "exact_amount" => "149.000123"
      },
      {
        "collection_method" => "direct_exact",
        "chain_namespace" => "tron",
        "chain_reference" => "0x2b6653dc",
        "currency" => "USD",
        "token_address" => "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
        "token_decimals" => 6,
        "network_label" => "TRON",
        "display_symbol" => "USDT",
        "logo_url" => nil,
        "chain_logo_url" => nil,
        "status" => "unavailable"
      }
    ]
  }.freeze

  # The create shape plus amount_paid and fully_paid_at, one revision on.
  PAID_TEST_INVOICE = INVOICE.merge(
    "status" => "paid",
    "checkout_status" => "paid",
    "payment_revision" => 1,
    "amount_paid" => "149.000000000000000000",
    "amount_due" => "0.000000000000000000",
    "fully_paid_at" => "2026-06-15T00:00:00.000Z"
  ).freeze

  # Invoice-level fields the backend replaced with payment_options; none of them
  # is a wire field any more.
  REMOVED_INVOICE_FIELDS = %w[
    deposit_address
    monitoring_status
    payment_status
    direct_onchain_rails
    rails
    network_fee_usd
    eta_seconds
  ].freeze

  # The snapshot at the moment the invoice was first fully paid.
  PAID_EVENT_INVOICE = {
    "id" => "inv_test",
    "mode" => "test",
    "status" => "paid",
    "amount" => "149.0000",
    "currency" => "USD",
    "amount_paid" => "149.000000000000000000",
    "reference_id" => "order_123",
    "payment_revision" => 1,
    "fully_paid_at" => "2026-06-15T00:00:00.000Z"
  }.freeze

  # The same invoice after a credited transfer was reversed.
  REVERSED_EVENT_INVOICE = PAID_EVENT_INVOICE.merge(
    "status" => "partially_paid",
    "amount_paid" => "20.000000000000000000",
    "payment_revision" => 2,
    "fully_paid_at" => nil
  ).freeze

  # Every field the shared envelope check requires of data.invoice.
  LIFECYCLE_INVOICE_FIELDS = %w[
    id
    mode
    status
    amount
    currency
    amount_paid
    reference_id
    payment_revision
    fully_paid_at
  ].freeze

  FakeResponse = Struct.new(:code, :body)

  def test_version
    assert_match(/\A\d+\.\d+\.\d+\z/, Invoq::VERSION)
  end

  def test_client_configuration
    client = Invoq.new("sk_test_123", api_origin: "https://api.example.com/", timeout_ms: 2_500)

    refute_includes client.inspect, "sk_test_123"
    assert_includes client.inspect, "https://api.example.com/"
    assert_includes client.inspect, "timeout_ms=2500"
    assert_instance_of Invoq::Client, client
  end

  def test_validates_api_keys_api_origin_and_timeout_ms
    assert_raises(Invoq::Error) { Invoq.new("") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "ftp://api.test") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://api.test/api") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://api.test/v1") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://user:pass@api.test") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://api.test?debug=1") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://api.test:bad") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://api.test:99999") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", api_origin: "https://[::1") }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", timeout_ms: 0) }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", timeout_ms: 1500.5) }
    assert_raises(Invoq::Error) { Invoq.new("sk_test_123", timeout_ms: 5_000_000_000) }
  end

  def test_creates_invoices_with_native_json_authorization_headers_and_timeout
    calls = []
    starts = []
    timeouts = []

    stub_timeout(timeouts) do
      stub_http(FakeResponse.new("201", JSON.generate("data" => INVOICE)), calls: calls, starts: starts) do
        client = Invoq.new("sk_test_123", api_origin: "https://api.test", timeout_ms: 2_500)
        result = client.invoices.create(
          amount: "149",
          description: "Test order",
          reference_id: "order_123",
          return_url: "https://merchant.test/thanks"
        )

        assert_equal INVOICE, result
        assert_equal "0.000000000000000000", result.fetch("amount_overpaid")
        assert_equal "unavailable", result.fetch("checkout_status")
        assert_equal 0, result.fetch("payment_revision")
        assert_equal [], result.fetch("payment_options")
        assert_nil result.fetch("monitoring_ends_at")
        refute_includes result, "transfers"

        REMOVED_INVOICE_FIELDS.each { |field| refute_includes result, field }
      end
    end

    request = calls.fetch(0)

    assert_equal "/v1/invoices", request.path
    assert_equal "POST", request.method
    assert_equal "Bearer sk_test_123", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal "invoq-ruby/#{Invoq::VERSION}", request["User-Agent"]
    assert_equal 2.5, timeouts.fetch(0)
    assert_equal 2.5, starts.fetch(0).fetch(:open_timeout)
    assert_equal 2.5, starts.fetch(0).fetch(:read_timeout)
    assert_equal 2.5, starts.fetch(0).fetch(:write_timeout)
    # No currency, no mode: the API rejects unknown body keys.
    assert_equal(
      {
        "amount" => "149",
        "description" => "Test order",
        "reference_id" => "order_123",
        "return_url" => "https://merchant.test/thanks"
      },
      JSON.parse(request.body)
    )
  end

  def test_omits_unset_optional_invoice_request_fields
    invoice = INVOICE.merge(
      "description" => nil,
      "reference_id" => nil,
      "return_url" => nil
    )
    calls = []

    stub_http(FakeResponse.new("201", JSON.generate("data" => invoice)), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.create("amount" => "149")

      assert_equal invoice, result
    end

    body = JSON.parse(calls.fetch(0).body)

    assert_equal({ "amount" => "149" }, body)
    refute_includes body, "description"
    refute_includes body, "reference_id"
    refute_includes body, "return_url"
  end

  # Callers still pass `currency` from older examples. It has to be dropped
  # here, not sent to an API that rejects unknown body keys with a
  # 400 invalid_request.
  def test_drops_hash_keys_that_are_not_request_fields
    calls = []

    stub_http(FakeResponse.new("201", JSON.generate("data" => INVOICE)), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")

      client.invoices.create(
        amount: "149",
        currency: "USD",
        mode: "live",
        payment_options: []
      )
      client.invoices.create(
        "amount" => "149",
        "currency" => "USD",
        "deposit_address" => "0xdead"
      )
      client.invoices.create_test_payment(
        "inv_test_123",
        amount: "149",
        currency: "USD"
      )
    end

    assert_equal 3, calls.length

    calls.each do |request|
      assert_equal({ "amount" => "149" }, JSON.parse(request.body))
    end
  end

  def test_accepts_nil_return_url_when_provided
    calls = []

    stub_http(FakeResponse.new("201", JSON.generate("data" => INVOICE.merge("return_url" => nil))), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")

      client.invoices.create(amount: "149", return_url: nil)
    end

    assert_equal({ "amount" => "149", "return_url" => nil }, JSON.parse(calls.fetch(0).body))
  end

  def test_rejects_invalid_invoice_request_fields
    client = Invoq.new("sk_test_123", api_origin: "https://api.test")

    assert_raises(Invoq::Error) { client.invoices.create("amount" => "149", "description" => nil) }
    assert_raises(Invoq::Error) { client.invoices.create(amount: "149", reference_id: nil) }
    assert_raises(Invoq::Error) { client.invoices.create("amount" => "149", "reference_id" => 123) }
    assert_raises(Invoq::Error) { client.invoices.create(amount: "149", return_url: 42) }
    assert_raises(Invoq::Error) { client.invoices.create(amount: "") }
    assert_raises(Invoq::Error) { client.invoices.create(amount: "  ") }
    assert_raises(Invoq::Error) { client.invoices.create(amount: 149) }
    assert_raises(Invoq::Error) { client.invoices.create("not a hash") }
  end

  def test_gets_public_invoices_by_id
    calls = []

    stub_http(FakeResponse.new("200", JSON.generate("data" => PUBLIC_INVOICE)), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.get("inv_live_123")

      assert_equal PUBLIC_INVOICE, result
      refute_includes result, "reference_id"
      assert_equal "Test project", result.fetch("project").fetch("name")
      assert_equal [], result.fetch("transfers")
      assert_equal "0.000000000000000000", result.fetch("amount_overpaid")
      assert_equal "open", result.fetch("checkout_status")
      assert_equal 0, result.fetch("payment_revision")

      REMOVED_INVOICE_FIELDS.each { |field| refute_includes result, field }

      options = result.fetch("payment_options")

      assert_equal 3, options.length
      assert_equal(
        "0x20c124f3919bb502c6126cda5bd6e5287859d5ca",
        options.fetch(0).fetch("deposit_address")
      )
      assert_equal "149.000123", options.fetch(1).fetch("exact_amount")
      assert_equal "unavailable", options.fetch(2).fetch("status")
      refute_includes options.fetch(2), "recipient_address"
    end

    request = calls.fetch(0)

    assert_equal "/v1/invoices/inv_live_123", request.path
    assert_equal "GET", request.method
    assert_nil request.body
    assert_equal "Bearer sk_test_123", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_nil request["Content-Type"]
    assert_equal "invoq-ruby/#{Invoq::VERSION}", request["User-Agent"]
  end

  def test_encodes_invoice_ids_as_path_segments
    calls = []

    stub_http(FakeResponse.new("200", JSON.generate("data" => PUBLIC_INVOICE)), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")

      client.invoices.get("inv /\u00E9")
    end

    assert_equal "/v1/invoices/inv%20%2F%C3%A9", calls.fetch(0).path
  end

  def test_returns_confirmed_transfers_verbatim
    transfer = {
      "chain_namespace" => "solana",
      "chain_reference" => "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
      "transaction_id" => "2Ana1pUpv2ZbMVkwF5FXapYeBEjdxDatLn7nvJkhgTSXbs59SyZSx866bXirPgj8QQVB57uxHJBG1YFvkRbFj4T",
      "event_index" => 2,
      "amount" => "149.000000000000000000",
      "explorer_transaction_url" => "https://solscan.io/tx/2Ana1pUpv2ZbMVkwF5FXapYeBEjdxDatLn7nvJkhgTSXbs59SyZSx866bXirPgj8QQVB57uxHJBG1YFvkRbFj4T"
    }
    paid_invoice = PUBLIC_INVOICE.merge(
      "status" => "settled",
      "checkout_status" => "paid",
      "payment_revision" => 1,
      "amount_paid" => "149.000000000000000000",
      "amount_due" => "0.000000000000000000",
      "transfers" => [transfer]
    )

    stub_http(FakeResponse.new("200", JSON.generate("data" => paid_invoice))) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.get("inv_live_123")

      assert_equal paid_invoice, result
      assert_equal [transfer], result.fetch("transfers")

      # Renamed by the backend: tx_hash and explorer_tx_url are gone.
      credit = result.fetch("transfers").fetch(0)

      assert_equal 2, credit.fetch("event_index")
      refute_includes credit, "tx_hash"
      refute_includes credit, "explorer_tx_url"
    end
  end

  def test_rejects_invalid_invoice_ids_before_fetch
    client = Invoq.new("sk_test_123", api_origin: "https://api.test")

    assert_raises(Invoq::Error) { client.invoices.get("") }
    assert_raises(Invoq::Error) { client.invoices.get("  ") }
    assert_raises(Invoq::Error) { client.invoices.get(123) }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("", amount: "1") }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("  ", amount: "1") }
  end

  def test_creates_test_payments_and_returns_only_data_envelope
    calls = []

    stub_http(
      FakeResponse.new("201", JSON.generate("data" => PAID_TEST_INVOICE, "meta" => { "result" => "created" })),
      calls: calls
    ) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.create_test_payment(
        "inv_test_123",
        "amount" => "149",
        "reference_id" => "test_payment_001"
      )

      assert_equal PAID_TEST_INVOICE, result
      assert_equal "0.000000000000000000", result.fetch("amount_overpaid")
      assert_equal "149.000000000000000000", result.fetch("amount_paid")
      assert_equal "2026-06-15T00:00:00.000Z", result.fetch("fully_paid_at")
      assert_equal 1, result.fetch("payment_revision")
      refute_includes result, "transfers"
      refute_includes result, "project"
    end

    request = calls.fetch(0)

    assert_equal "/v1/invoices/inv_test_123/test-payments", request.path
    assert_equal(
      {
        "amount" => "149",
        "reference_id" => "test_payment_001"
      },
      JSON.parse(request.body)
    )
  end

  def test_omits_unset_optional_test_payment_request_fields
    paid_invoice = PAID_TEST_INVOICE.merge("reference_id" => nil)
    calls = []

    stub_http(FakeResponse.new("201", JSON.generate("data" => paid_invoice)), calls: calls) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.create_test_payment(
        "inv_test_123",
        "amount" => "149"
      )

      assert_equal paid_invoice, result
    end

    body = JSON.parse(calls.fetch(0).body)

    assert_equal({ "amount" => "149" }, body)
    refute_includes body, "reference_id"
  end

  def test_rejects_invalid_test_payment_request_fields
    client = Invoq.new("sk_test_123", api_origin: "https://api.test")

    assert_raises(Invoq::Error) { client.invoices.create_test_payment("inv_test_123", "amount" => "149", "reference_id" => nil) }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("inv_test_123", amount: "149", reference_id: nil) }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("inv_test_123", "amount" => "149", "reference_id" => 123) }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("inv_test_123", amount: "") }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("inv_test_123", amount: "  ") }
  end

  def test_rejects_an_api_key_with_control_characters
    ["sk_test_x\r\nX-Injected: yes", "sk_test_x\n", "sk_test\u0000x"].each do |key|
      error = assert_raises(Invoq::Error) { Invoq.new(key) }
      assert_includes error.message, "control characters"
    end
  end

  def test_rejects_a_trailing_comma_in_the_signature_header
    error = assert_raises(Invoq::SignatureVerificationError) do
      Invoq::Webhooks.verify_webhook(
        "{}",
        { "invoq-signature" => "t=#{Time.now.to_i},v1=#{"a" * 64}," },
        "whsec_test"
      )
    end

    assert_equal "invalid_signature_header", error.code
  end

  def test_keys_the_hmac_on_the_secrets_raw_bytes
    body = "{\"type\":\"invoice.paid\"}"
    secret = "whsec_caf\xE9".dup.force_encoding("ISO-8859-1")
    timestamp = Time.now.to_i
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret.b, "#{timestamp}.#{body}")

    event = Invoq::Webhooks.verify_webhook(
      body,
      { "invoq-signature" => "t=#{timestamp},v1=#{expected}" },
      secret
    )

    assert_equal "invoice.paid", event["type"]
  end

  def test_rejects_a_non_object_data_envelope
    ["null", "5", "[]", "\"x\""].each do |body|
      error = assert_raises(Invoq::Error) do
        stub_http(FakeResponse.new("200", "{\"data\":#{body}}")) do
          Invoq.new("sk_test_123").invoices.create("amount" => "1")
        end
      end

      assert_includes error.message, "data envelope was not an object"
    end
  end

  def test_rejects_a_dot_segment_invoice_id
    client = Invoq.new("sk_test_123")

    [".", ".."].each do |id|
      assert_raises(Invoq::Error) { client.invoices.get(id) }
      assert_raises(Invoq::Error) { client.invoices.create_test_payment(id, "amount" => "1") }
    end
  end

  def test_maps_api_error_envelopes_to_invoq_api_error
    payload = {
      "code" => "invalid_request",
      "message" => "Invalid request.",
      "fields" => [
        {
          "location" => "body",
          "field" => "amount",
          "code" => "required",
          "message" => "Required."
        },
        {
          "location" => "unexpected",
          "field" => "currency",
          "code" => "unknown_field",
          "message" => "Unknown field."
        },
        { "location" => "body", "field" => "description", "message" => "No code." }
      ],
      "meta" => { "request_id" => "req_test" }
    }

    error = assert_raises(Invoq::ApiError) do
      stub_http(FakeResponse.new("400", JSON.generate(payload))) do
        Invoq.new("sk_test_123").invoices.create("amount" => "0.001")
      end
    end

    assert_equal 400, error.status
    assert_equal "invalid_request", error.code
    assert_equal payload["fields"].first(2), error.fields
    assert_equal({ "request_id" => "req_test" }, error.meta)
  end

  def test_preserves_empty_api_error_fields
    error = assert_raises(Invoq::ApiError) do
      stub_http(
        FakeResponse.new(
          "400",
          JSON.generate(
            "code" => "invalid_request",
            "message" => "Invalid request.",
            "fields" => []
          )
        )
      ) do
        Invoq.new("sk_test_123").invoices.create("amount" => "0.001")
      end
    end

    assert_equal [], error.fields
  end

  def test_maps_non_json_http_errors_to_invoq_api_error
    error = assert_raises(Invoq::ApiError) do
      stub_http(FakeResponse.new("502", "<html>bad gateway</html>")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1")
      end
    end

    assert_equal 502, error.status
    assert_equal "<html>bad gateway</html>", error.payload
  end

  def test_maps_timeout_network_and_response_parse_failures_to_invoq_error
    error = assert_raises(Invoq::Error) do
      stub_http(Net::ReadTimeout.new("timed out")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1")
      end
    end

    assert_equal "invoq API request timed out.", error.message

    assert_raises(Invoq::Error) do
      stub_http(StandardError.new("boom")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1")
      end
    end

    assert_raises(Invoq::Error) do
      stub_http(FakeResponse.new("200", "not json")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1")
      end
    end
  end

  # An event type this version does not model: verification is shape-agnostic,
  # so a new backend event never fails on an older SDK.
  def test_verify_webhook_string_payload
    secret = "whsec_test_123"
    timestamp = 1_710_000_000
    body = '{"id":"evt_test","type":"invoice.future_event","data":{"invoice":{"id":"inv_test"}}}'
    header = "t=1710000000,v1=7882995406911f86ee0e8a85feba7e21befe10ead08701ff7ff066738ca4c28e"

    freeze_time(timestamp) do
      assert_equal(
        {
          "id" => "evt_test",
          "type" => "invoice.future_event",
          "data" => {
            "invoice" => {
              "id" => "inv_test"
            }
          }
        },
        Invoq.verify_webhook(body, { "invoq-signature" => header }, secret)
      )
    end
  end

  def test_verify_webhook_case_insensitive_array_headers
    secret = "whsec_test_123"
    timestamp = 1_710_000_001
    body = [
      "7b226964223a226576745f6279746573222c2274797065223a22696e766f6963652e6675747572",
      "655f6576656e74222c2264617461223a7b22696e766f696365223a7b226964223a22696e765f62",
      "79746573227d7d7d"
    ].join.scan(/../).map { |byte| byte.to_i(16).chr }.join
    header = "t=1710000001,v1=fa0fde1c5d73fe059235b19dc1d7785e1d3c695e055dfcfa8f69a1202bacee37"

    freeze_time(timestamp) do
      event = Invoq.verify_webhook(body, { "Invoq-Signature" => [header] }, secret)

      assert_equal "evt_bytes", event["id"]
      assert_equal "invoice.future_event", event["type"]
    end
  end

  def test_verify_webhook_uses_last_v1_signature
    secret = "whsec_test_123"
    timestamp = 1_710_000_000
    body = '{"id":"evt_test","type":"invoice.future_event"}'
    valid_signature = sign(body, timestamp, secret).split("v1=").fetch(1)
    invalid_signature = "0" * 64

    freeze_time(timestamp) do
      event = Invoq.verify_webhook(
        body,
        { "invoq-signature" => "t=#{timestamp},v1=#{invalid_signature},v1=#{valid_signature}" },
        secret
      )

      assert_equal "evt_test", event["id"]

      assert_signature_error("signature_mismatch") do
        Invoq.verify_webhook(
          body,
          { "invoq-signature" => "t=#{timestamp},v1=#{valid_signature},v1=#{invalid_signature}" },
          secret
        )
      end
    end
  end

  def test_verify_webhook_rejects_invalid_inputs
    secret = "whsec_test_123"
    timestamp = 1_710_000_000
    body = '{"id":"evt_test","type":"invoice.future_event"}'
    header = sign(body, timestamp, secret)

    freeze_time(timestamp) do
      assert_signature_error("missing_signature") do
        Invoq.verify_webhook(body, {}, secret)
      end

      assert_signature_error("missing_signature") do
        Invoq.verify_webhook(body, nil, secret)
      end

      assert_signature_error("missing_signature") do
        Invoq.verify_webhook(body, "not headers", secret)
      end

      assert_signature_error("invalid_signature_header") do
        Invoq.verify_webhook(body, { "invoq-signature" => "v1=abc" }, secret)
      end
    end

    freeze_time(timestamp + 301) do
      assert_signature_error("timestamp_outside_tolerance") do
        Invoq.verify_webhook(body, { "invoq-signature" => header }, secret)
      end
    end

    freeze_time(timestamp) do
      assert_signature_error("signature_mismatch") do
        Invoq.verify_webhook(body, { "invoq-signature" => header }, "wrong")
      end

      assert_signature_error("invalid_payload") do
        Invoq.verify_webhook("not json", { "invoq-signature" => sign("not json", timestamp, secret) }, secret)
      end

      assert_signature_error("invalid_payload") do
        Invoq.verify_webhook("[]", { "invoq-signature" => sign("[]", timestamp, secret) }, secret)
      end

      assert_signature_error("invalid_payload") do
        Invoq.verify_webhook('{"id":"evt"}', { "invoq-signature" => sign('{"id":"evt"}', timestamp, secret) }, secret)
      end
    end
  end

  def test_invoice_paid_accepts_every_paid_equivalent_status
    %w[paid settling settled].each do |status|
      event = lifecycle_event("invoice.paid", PAID_EVENT_INVOICE.merge("status" => status))

      assert Invoq.invoice_paid?(event)
      assert Invoq.is_invoice_paid(event)
    end
  end

  def test_invoice_paid_checks_the_full_invoice_shape
    LIFECYCLE_INVOICE_FIELDS.each do |field|
      refute Invoq.invoice_paid?(
        lifecycle_event("invoice.paid", without_field(PAID_EVENT_INVOICE, field))
      )
    end

    refute Invoq.invoice_paid?(
      lifecycle_event("invoice.paid", PAID_EVENT_INVOICE.merge("payment_revision" => "1"))
    )
  end

  def test_invoice_paid_rejects_mangled_envelopes
    %w[id mode created_at data].each do |field|
      refute Invoq.invoice_paid?(
        without_field(lifecycle_event("invoice.paid", PAID_EVENT_INVOICE), field)
      )
    end

    refute Invoq.invoice_paid?(nil)
    refute Invoq.invoice_paid?("not an event")
  end

  def test_invoice_paid_rejects_statuses_that_are_not_cleared_for_fulfillment
    %w[review_required partially_paid unpaid unexpected].each do |status|
      refute Invoq.invoice_paid?(
        lifecycle_event("invoice.paid", PAID_EVENT_INVOICE.merge("status" => status))
      )
    end
  end

  def test_invoice_paid_rejects_reversals_whatever_they_reverted_the_invoice_to
    refute Invoq.invoice_paid?(
      lifecycle_event("invoice.payment_reversed", REVERSED_EVENT_INVOICE)
    )
    refute Invoq.invoice_paid?(
      lifecycle_event("invoice.payment_reversed", REVERSED_EVENT_INVOICE.merge("status" => "paid"))
    )
  end

  def test_invoice_payment_reversed_accepts_a_reversal_in_any_status
    # Fails open, unlike the paid guard: a reversal this version cannot classify
    # must still reach the merchant.
    %w[unpaid partially_paid review_required paid settling settled unexpected].each do |status|
      event = lifecycle_event(
        "invoice.payment_reversed",
        REVERSED_EVENT_INVOICE.merge("status" => status)
      )

      assert Invoq.invoice_payment_reversed?(event)
      assert Invoq.is_invoice_payment_reversed(event)
    end
  end

  def test_invoice_payment_reversed_checks_the_same_shared_invoice_shape
    LIFECYCLE_INVOICE_FIELDS.each do |field|
      refute Invoq.invoice_payment_reversed?(
        lifecycle_event("invoice.payment_reversed", without_field(REVERSED_EVENT_INVOICE, field))
      )
    end

    refute Invoq.invoice_payment_reversed?(
      lifecycle_event(
        "invoice.payment_reversed",
        REVERSED_EVENT_INVOICE.merge("payment_revision" => 2.5)
      )
    )
  end

  def test_invoice_payment_reversed_rejects_paid_events
    refute Invoq.invoice_payment_reversed?(
      lifecycle_event("invoice.paid", PAID_EVENT_INVOICE)
    )
  end

  private

  def lifecycle_event(type, invoice)
    {
      "id" => "wdel_test",
      "type" => type,
      "mode" => "test",
      "created_at" => "2026-06-15T00:00:00.000Z",
      "data" => { "invoice" => invoice }
    }
  end

  def without_field(hash, field)
    rest = hash.dup
    rest.delete(field)
    rest
  end

  def stub_http(response_or_error, calls: [], starts: [])
    start = lambda do |_host, _port, *args, **kwargs, &block|
      starts << kwargs
      http = Object.new
      http.define_singleton_method(:request) do |request|
        calls << request
        raise response_or_error if response_or_error.is_a?(Exception)

        response_or_error
      end

      block.call(http)
    end

    Net::HTTP.stub(:start, start) { yield }
  end

  def stub_timeout(calls)
    timeout = lambda do |seconds, *args, &block|
      calls << seconds
      block.call
    end

    Timeout.stub(:timeout, timeout) { yield }
  end

  def freeze_time(timestamp)
    Time.stub(:now, Time.at(timestamp)) { yield }
  end

  def sign(payload, timestamp, secret)
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    "t=#{timestamp},v1=#{signature}"
  end

  def assert_signature_error(code)
    error = assert_raises(Invoq::SignatureVerificationError) do
      yield
    end

    assert_equal code, error.code
  end
end
