# frozen_string_literal: true

require_relative "errors"
require_relative "internal/request"

module Invoq
  class InvoicesResource
    MISSING = Object.new

    def initialize(api_key:, api_origin:, timeout_ms:)
      @api_key = api_key
      @api_origin = api_origin
      @timeout_ms = timeout_ms
    end

    def create(input)
      Internal::Request.json(
        api_key: @api_key,
        api_origin: @api_origin,
        timeout_ms: @timeout_ms,
        path: "/v1/invoices",
        body: create_invoice_request_body(input)
      )
    end

    def get(invoice_id)
      id = encode_path_segment(required_request_string(invoice_id, "invoice_id"))

      Internal::Request.json(
        api_key: @api_key,
        api_origin: @api_origin,
        timeout_ms: @timeout_ms,
        method: "GET",
        path: "/v1/invoices/#{id}"
      )
    end

    def create_test_payment(invoice_id, input)
      id = encode_path_segment(required_request_string(invoice_id, "invoice_id"))

      Internal::Request.json(
        api_key: @api_key,
        api_origin: @api_origin,
        timeout_ms: @timeout_ms,
        path: "/v1/invoices/#{id}/test-payments",
        body: create_test_payment_request_body(input)
      )
    end

    private

    def create_invoice_request_body(input)
      unless input.is_a?(Hash)
        raise Error, "request body must be a hash."
      end

      body = {
        "amount" => required_request_string(input_value(input, "amount"), "amount")
      }
      currency = optional_request_value(input, "currency")
      description = optional_request_string(input, "description")
      reference_id = optional_request_string(input, "reference_id")
      return_url = optional_nullable_request_string(input, "return_url")

      body["currency"] = currency unless currency.equal?(MISSING)
      body["description"] = description unless description.equal?(MISSING)
      body["reference_id"] = reference_id unless reference_id.equal?(MISSING)
      body["return_url"] = return_url unless return_url.equal?(MISSING)

      body
    end

    def create_test_payment_request_body(input)
      unless input.is_a?(Hash)
        raise Error, "request body must be a hash."
      end

      body = {
        "amount" => required_request_string(input_value(input, "amount"), "amount")
      }
      reference_id = optional_request_string(input, "reference_id")

      body["reference_id"] = reference_id unless reference_id.equal?(MISSING)

      body
    end

    def optional_request_string(input, field)
      value = optional_request_value(input, field)
      return MISSING if value.equal?(MISSING)

      unless value.is_a?(String)
        raise Error, "#{field} must be a string when provided."
      end

      value
    end

    def optional_nullable_request_string(input, field)
      value = optional_request_value(input, field)
      return MISSING if value.equal?(MISSING)

      unless value.nil? || value.is_a?(String)
        raise Error, "#{field} must be a string or nil when provided."
      end

      value
    end

    def required_request_string(value, field)
      unless value.is_a?(String) && !value.strip.empty?
        raise Error, "#{field} must be a non-empty string."
      end

      value
    end

    def optional_request_value(input, field)
      if input.key?(field)
        input[field]
      elsif input.key?(field.to_sym)
        input[field.to_sym]
      else
        MISSING
      end
    end

    def input_value(input, field)
      return input[field] if input.key?(field)

      input[field.to_sym]
    end

    def encode_path_segment(value)
      value.encode("UTF-8").bytes.map do |byte|
        if unescaped_path_byte?(byte)
          byte.chr
        else
          format("%%%02X", byte)
        end
      end.join
    end

    def unescaped_path_byte?(byte)
      case byte
      when 65..90, 97..122, 48..57, 45, 95, 46, 33, 126, 42, 39, 40, 41
        true
      else
        false
      end
    end
  end
end
