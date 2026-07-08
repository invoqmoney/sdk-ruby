# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "openssl"

require "invoq"
require "invoq/internal/request"

class InvoqTest < Minitest::Test
  INVOICE = {
    "id" => "inv_test_123",
    "mode" => "test",
    "amount" => "149.0000",
    "currency" => "USD",
    "reference_id" => "order_123",
    "description" => "Test order",
    "return_url" => "https://merchant.test/thanks",
    "deposit_address" => nil,
    "status" => "unpaid",
    "amount_due" => "149.000000000000000000",
    "monitoring_ends_at" => nil,
    "direct_onchain_rails" => []
  }.freeze

  PUBLIC_INVOICE = {
    "id" => "inv_test_123",
    "mode" => "test",
    "amount" => "149.0000",
    "currency" => "USD",
    "description" => "Test order",
    "return_url" => nil,
    "project" => {
      "id" => "proj_test_123",
      "name" => "Test project",
      "logo_url" => nil
    },
    "deposit_address" => nil,
    "status" => "unpaid",
    "amount_due" => "149.000000000000000000",
    "monitoring_ends_at" => nil,
    "direct_onchain_rails" => [],
    "amount_paid" => "0.000000000000000000",
    "payment_status" => "unpaid"
  }.freeze

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
          currency: "USD",
          description: "Test order",
          reference_id: "order_123",
          return_url: "https://merchant.test/thanks"
        )

        assert_equal INVOICE, result
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
    assert_equal(
      {
        "amount" => "149",
        "currency" => "USD",
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
      result = client.invoices.create(
        "amount" => "149",
        "currency" => "USD"
      )

      assert_equal invoice, result
    end

    body = JSON.parse(calls.fetch(0).body)

    assert_equal({ "amount" => "149", "currency" => "USD" }, body)
    refute_includes body, "description"
    refute_includes body, "reference_id"
    refute_includes body, "return_url"
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
      result = client.invoices.get("inv_test_123")

      assert_equal PUBLIC_INVOICE, result
      refute_includes result, "reference_id"
      assert_equal "Test project", result.fetch("project").fetch("name")
    end

    request = calls.fetch(0)

    assert_equal "/v1/invoices/inv_test_123", request.path
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

  def test_rejects_invalid_invoice_ids_before_fetch
    client = Invoq.new("sk_test_123", api_origin: "https://api.test")

    assert_raises(Invoq::Error) { client.invoices.get("") }
    assert_raises(Invoq::Error) { client.invoices.get("  ") }
    assert_raises(Invoq::Error) { client.invoices.get(123) }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("", amount: "1") }
    assert_raises(Invoq::Error) { client.invoices.create_test_payment("  ", amount: "1") }
  end

  def test_creates_test_payments_and_returns_only_data_envelope
    paid_invoice = INVOICE.merge(
      "status" => "paid",
      "amount_paid" => "149.000000000000000000",
      "amount_due" => "0.000000000000000000",
      "fully_paid_at" => "2026-06-15T00:00:00.000Z"
    )
    calls = []

    stub_http(
      FakeResponse.new("201", JSON.generate("data" => paid_invoice, "meta" => { "result" => "created" })),
      calls: calls
    ) do
      client = Invoq.new("sk_test_123", api_origin: "https://api.test")
      result = client.invoices.create_test_payment(
        "inv_test_123",
        "amount" => "149",
        "reference_id" => "test_payment_001"
      )

      assert_equal paid_invoice, result
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
    paid_invoice = INVOICE.merge(
      "status" => "paid",
      "amount_paid" => "149.000000000000000000",
      "amount_due" => "0.000000000000000000",
      "fully_paid_at" => "2026-06-15T00:00:00.000Z",
      "reference_id" => nil
    )
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
        }
      ],
      "meta" => { "request_id" => "req_test" }
    }

    error = assert_raises(Invoq::ApiError) do
      stub_http(FakeResponse.new("400", JSON.generate(payload))) do
        Invoq.new("sk_test_123").invoices.create("amount" => "0.001", "currency" => "USD")
      end
    end

    assert_equal 400, error.status
    assert_equal "invalid_request", error.code
    assert_equal payload["fields"], error.fields
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
        Invoq.new("sk_test_123").invoices.create("amount" => "0.001", "currency" => "USD")
      end
    end

    assert_equal [], error.fields
  end

  def test_maps_non_json_http_errors_to_invoq_api_error
    error = assert_raises(Invoq::ApiError) do
      stub_http(FakeResponse.new("502", "<html>bad gateway</html>")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1", "currency" => "USD")
      end
    end

    assert_equal 502, error.status
    assert_equal "<html>bad gateway</html>", error.payload
  end

  def test_maps_timeout_network_and_response_parse_failures_to_invoq_error
    error = assert_raises(Invoq::Error) do
      stub_http(Net::ReadTimeout.new("timed out")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1", "currency" => "USD")
      end
    end

    assert_equal "invoq API request timed out.", error.message

    assert_raises(Invoq::Error) do
      stub_http(StandardError.new("boom")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1", "currency" => "USD")
      end
    end

    assert_raises(Invoq::Error) do
      stub_http(FakeResponse.new("200", "not json")) do
        Invoq.new("sk_test_123").invoices.create("amount" => "1", "currency" => "USD")
      end
    end
  end

  def test_verify_webhook_string_payload
    secret = "whsec_test_123"
    timestamp = 1_710_000_000
    body = '{"id":"evt_test","type":"webhook.ping","data":{"project":{"id":"proj_test"}}}'
    header = "t=1710000000,v1=eeafd628acb4e854f5fd942644490b313220dcc7906303d0c8572050ee7795ff"

    freeze_time(timestamp) do
      assert_equal(
        {
          "id" => "evt_test",
          "type" => "webhook.ping",
          "data" => {
            "project" => {
              "id" => "proj_test"
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
      "7b226964223a226576745f6279746573222c2274797065223a22776562686f6f6b2e70696e67222c",
      "2264617461223a7b2270726f6a656374223a7b226964223a2270726f6a5f6279746573227d7d7d"
    ].join.scan(/../).map { |byte| byte.to_i(16).chr }.join
    header = "t=1710000001,v1=1ee237dd9e509e515eca754c3a34da3536e8c76cfc8ce1fd0a4e74d1366d20e2"

    freeze_time(timestamp) do
      event = Invoq.verify_webhook(body, { "Invoq-Signature" => [header] }, secret)

      assert_equal "evt_bytes", event["id"]
      assert_equal "webhook.ping", event["type"]
    end
  end

  def test_verify_webhook_uses_last_v1_signature
    secret = "whsec_test_123"
    timestamp = 1_710_000_000
    body = '{"id":"evt_test","type":"webhook.ping"}'
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
    body = '{"id":"evt_test","type":"webhook.ping"}'
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

  def test_invoice_paid_checks_full_shape_and_paid_statuses
    event = {
      "id" => "evt_paid",
      "type" => "invoice.paid",
      "mode" => "test",
      "created_at" => "2026-06-15T00:00:00.000Z",
      "data" => {
        "invoice" => {
          "id" => "inv_test",
          "mode" => "test",
          "status" => "paid",
          "amount" => "149.0000",
          "currency" => "USD",
          "amount_paid" => "149.000000000000000000",
          "reference_id" => "order_123",
          "fully_paid_at" => "2026-06-15T00:00:00.000Z"
        }
      }
    }

    assert Invoq.invoice_paid?(event)
    assert Invoq.is_invoice_paid(event)

    event["data"]["invoice"]["status"] = "settling"
    assert Invoq.invoice_paid?(event)

    event["data"]["invoice"]["status"] = "settled"
    assert Invoq.invoice_paid?(event)

    event["data"]["invoice"]["status"] = "review_required"
    refute Invoq.invoice_paid?(event)

    event["data"]["invoice"]["status"] = "unexpected"
    refute Invoq.invoice_paid?(event)

    event["data"]["invoice"]["status"] = "paid"
    event["data"]["invoice"].delete("amount_paid")
    refute Invoq.invoice_paid?(event)
  end

  private

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
