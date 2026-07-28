# frozen_string_literal: true

require "uri"

require_relative "errors"
require_relative "invoices_resource"

module Invoq
  DEFAULT_API_ORIGIN = "https://api.invoq.money"
  DEFAULT_TIMEOUT_MS = 10_000
  MAX_TIMEOUT_MS = 4_294_967_295

  class Client
    attr_reader :invoices

    def initialize(api_key, api_origin: DEFAULT_API_ORIGIN, timeout_ms: DEFAULT_TIMEOUT_MS)
      unless api_key.is_a?(String) && !api_key.strip.empty?
        raise Error, "invoq API key must be a non-empty string."
      end

      # A control character in a key is either rejected deep in the transport or
      # silently sent; reject it here so every SDK answers the same way.
      if api_key.match?(/[\x00-\x1F\x7F]/)
        raise Error, "invoq API key must not contain control characters."
      end

      @api_key = api_key
      @api_origin = Invoq.normalize_api_origin(api_origin)
      @timeout_ms = Invoq.normalize_timeout_ms(timeout_ms)
      @invoices = InvoicesResource.new(
        api_key: @api_key,
        api_origin: @api_origin,
        timeout_ms: @timeout_ms
      )
    end

    def inspect
      "#<#{self.class} api_origin=#{@api_origin.inspect} timeout_ms=#{@timeout_ms.inspect}>"
    end
  end

  def self.normalize_api_origin(value)
    unless value.is_a?(String)
      raise Error, "api_origin must be an absolute http or https origin."
    end

    uri = URI.parse(value)

    unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
      raise Error, "api_origin must be an absolute http or https origin."
    end

    unless uri.scheme == "http" || uri.scheme == "https"
      raise Error, "api_origin must be an absolute http or https origin."
    end

    if uri.user || uri.password
      raise Error, "api_origin must be an absolute http or https origin."
    end

    if uri.port < 1 || uri.port > 65_535
      raise Error, "api_origin must be an absolute http or https origin."
    end

    if uri.query || uri.fragment
      raise Error, "api_origin must not include query or hash parts."
    end

    pathname = uri.path.to_s.sub(%r{/+\z}, "")
    pathname = "/" if pathname.empty?

    unless pathname == "/"
      raise Error, "api_origin must not include a path."
    end

    uri.path = "/"
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    raise Error, "api_origin must be an absolute http or https origin."
  end

  def self.normalize_timeout_ms(value)
    unless value.is_a?(Integer) && value.positive? && value <= MAX_TIMEOUT_MS
      raise Error, "timeout_ms must be a positive integer of at most 4294967295."
    end

    value
  end
end
