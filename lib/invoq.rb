# frozen_string_literal: true

require_relative "invoq/version"
require_relative "invoq/errors"
require_relative "invoq/client"
require_relative "invoq/webhooks"

module Invoq
  def self.new(api_key, api_origin: DEFAULT_API_ORIGIN, timeout_ms: DEFAULT_TIMEOUT_MS)
    Client.new(api_key, api_origin: api_origin, timeout_ms: timeout_ms)
  end

  def self.verify_webhook(raw_body, headers, webhook_secret)
    Webhooks.verify_webhook(raw_body, headers, webhook_secret)
  end

  def self.invoice_paid?(event)
    Webhooks.invoice_paid?(event)
  end

  def self.is_invoice_paid(event)
    invoice_paid?(event)
  end
end
