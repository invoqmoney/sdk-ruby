# frozen_string_literal: true

module Invoq
  class Error < StandardError
    attr_reader :payload

    def initialize(message = nil, payload: nil)
      super(message)
      @payload = payload
    end
  end

  class ApiError < Error
    attr_reader :status, :code, :fields, :meta

    def initialize(message, status:, code: nil, fields: nil, meta: nil, payload: nil)
      super(message, payload: payload)
      @status = status
      @code = code
      @fields = fields
      @meta = meta
    end
  end

  class SignatureVerificationError < Error
    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end
end
