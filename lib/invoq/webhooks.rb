# frozen_string_literal: true

require "json"
require "openssl"

require_relative "errors"

module Invoq
  module Webhooks
    DEFAULT_TOLERANCE_SECONDS = 300
    SIGNATURE_PATTERN = /\A[a-f0-9]{64}\z/i
    MISSING = Object.new

    def self.verify_webhook(raw_body, headers, webhook_secret)
      signature_header = get_signature_header(headers)

      if signature_header.nil? || signature_header.empty?
        raise signature_error("missing_signature", "Missing invoq-signature header.")
      end

      unless webhook_secret.is_a?(String) && !webhook_secret.empty?
        raise signature_error(
          "invalid_signature_header",
          "Webhook secret must be a non-empty string."
        )
      end

      timestamp, timestamp_seconds, signature = parse_signature_header(signature_header)
      now_seconds = Time.now.to_i

      if (now_seconds - timestamp_seconds).abs > DEFAULT_TOLERANCE_SECONDS
        raise signature_error(
          "timestamp_outside_tolerance",
          "Webhook timestamp is outside the allowed tolerance."
        )
      end

      expected_signature = hmac_sha256_hex(webhook_secret, timestamp, raw_body)

      unless constant_time_equal?(expected_signature, signature)
        raise signature_error("signature_mismatch", "Webhook signature mismatch.")
      end

      payload = JSON.parse(body_text(raw_body))

      unless payload.is_a?(Hash) && payload["type"].is_a?(String)
        raise signature_error(
          "invalid_payload",
          "Webhook payload must be an object with a string type."
        )
      end

      payload
    rescue JSON::ParserError
      raise signature_error("invalid_payload", "Webhook payload is not valid JSON.")
    end

    def self.invoice_paid?(event)
      invoice = lifecycle_event_invoice(event, "invoice.paid")

      # Paid-equivalent statuses only: review_required has money against it but
      # is not cleared for fulfillment.
      !invoice.nil? && invoice_paid_status?(invoice["status"])
    end

    def self.is_invoice_paid(event)
      invoice_paid?(event)
    end

    def self.invoice_payment_reversed?(event)
      # No status check, unlike the paid guard: rejecting an unrecognized status
      # would drop the event and leave the order fulfilled on a payment that no
      # longer exists.
      !lifecycle_event_invoice(event, "invoice.payment_reversed").nil?
    end

    def self.is_invoice_payment_reversed(event)
      invoice_payment_reversed?(event)
    end

    # The fields both lifecycle events share, returned so each guard can apply
    # its own status rule. nil when this is not a well-formed event of that type.
    def self.lifecycle_event_invoice(event, type)
      return nil unless event.is_a?(Hash)
      return nil unless event["type"] == type
      return nil unless event["id"].is_a?(String)
      return nil unless invoice_mode?(event["mode"])
      return nil unless event["created_at"].is_a?(String)

      data = event["data"]
      return nil unless data.is_a?(Hash)

      invoice = data["invoice"]
      return nil unless invoice.is_a?(Hash)

      reference_id = invoice.key?("reference_id") ? invoice["reference_id"] : MISSING
      fully_paid_at = invoice.key?("fully_paid_at") ? invoice["fully_paid_at"] : MISSING

      valid = invoice["id"].is_a?(String) &&
        invoice_mode?(invoice["mode"]) &&
        invoice["status"].is_a?(String) &&
        invoice["amount"].is_a?(String) &&
        invoice["currency"] == "USD" &&
        invoice["amount_paid"].is_a?(String) &&
        (reference_id.is_a?(String) || reference_id.nil?) &&
        invoice["payment_revision"].is_a?(Integer) &&
        (fully_paid_at.is_a?(String) || fully_paid_at.nil?)

      valid ? invoice : nil
    end
    private_class_method :lifecycle_event_invoice

    def self.parse_signature_header(signature_header)
      parts = {}

      signature_header.split(",").each do |part|
        separator_index = part.index("=")

        unless separator_index
          raise signature_error(
            "invalid_signature_header",
            "Invalid invoq-signature header."
          )
        end

        key = part[0...separator_index].strip
        value = part[(separator_index + 1)..-1].to_s.strip
        next if key.empty? || value.empty?

        parts[key] = value
      end

      timestamp = parts["t"]
      signature = parts["v1"]

      unless timestamp && signature && timestamp.match?(/\A\d+\z/)
        raise signature_error(
          "invalid_signature_header",
          "Invalid invoq-signature header."
        )
      end

      unless signature.match?(SIGNATURE_PATTERN)
        raise signature_error(
          "invalid_signature_header",
          "Invalid invoq-signature signature."
        )
      end

      [timestamp, timestamp.to_i, signature.downcase]
    end
    private_class_method :parse_signature_header

    def self.get_signature_header(headers)
      return nil if headers.nil?
      return nil unless headers.respond_to?(:each)

      headers.each do |key, value|
        next unless key.to_s.downcase == "invoq-signature"

        return nil if value.nil?
        return value.map(&:to_s).join(",") if value.is_a?(Array)

        return value.to_s
      end

      nil
    end
    private_class_method :get_signature_header

    def self.hmac_sha256_hex(secret, timestamp, raw_body)
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        secret.encode("UTF-8"),
        "#{timestamp}.".b + body_bytes(raw_body)
      )
    end
    private_class_method :hmac_sha256_hex

    def self.body_text(raw_body)
      body_bytes(raw_body).force_encoding("UTF-8")
    end
    private_class_method :body_text

    def self.body_bytes(raw_body)
      unless raw_body.is_a?(String)
        raise signature_error("invalid_payload", "Webhook payload is not valid JSON.")
      end

      raw_body.b
    end
    private_class_method :body_bytes

    def self.constant_time_equal?(left, right)
      left_bytes = left.b.bytes
      right_bytes = right.b.bytes
      max_length = [left_bytes.length, right_bytes.length, 1].max
      result = left_bytes.length ^ right_bytes.length

      max_length.times do |index|
        result |= (left_bytes[index] || 0) ^ (right_bytes[index] || 0)
      end

      result.zero?
    end
    private_class_method :constant_time_equal?

    def self.invoice_mode?(value)
      value == "test" || value == "live"
    end
    private_class_method :invoice_mode?

    def self.invoice_paid_status?(value)
      value == "paid" || value == "settling" || value == "settled"
    end
    private_class_method :invoice_paid_status?

    def self.signature_error(code, message)
      SignatureVerificationError.new(code, message)
    end
    private_class_method :signature_error
  end
end
