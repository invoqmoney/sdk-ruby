# frozen_string_literal: true

require "json"
require "net/http"
require "timeout"
require "uri"

require_relative "../errors"
require_relative "../version"

module Invoq
  module Internal
    class Request
      NO_BODY = Object.new
      USER_AGENT = "invoq-ruby/#{Invoq::VERSION}"

      def self.json(api_key:, api_origin:, timeout_ms:, path:, method: "POST", body: NO_BODY)
        url = URI.parse(api_origin + path.sub(%r{\A/+}, ""))
        request = build_request(url, method)
        request["Accept"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}"
        request["User-Agent"] = USER_AGENT

        unless body.equal?(NO_BODY)
          request.body = JSON.generate(body)
          request["Content-Type"] = "application/json"
        end

        response = perform_request(url, request, timeout_ms)
        status = response.code.to_i
        response_text = response.body.to_s

        begin
          payload = JSON.parse(response_text)
        rescue JSON::ParserError
          if status < 200 || status >= 300
            raise api_error_from_response(status, response_text)
          end

          raise Error, "Failed to parse invoq API response."
        end

        if status < 200 || status >= 300
          raise api_error_from_response(status, payload)
        end

        unless payload.is_a?(Hash) && payload.key?("data")
          raise Error.new(
            "invoq API response did not include a data envelope.",
            payload: payload
          )
        end

        payload["data"]
      rescue JSON::GeneratorError
        raise Error, "Failed to encode invoq API request."
      end

      def self.build_request(url, method)
        case method
        when "GET"
          Net::HTTP::Get.new(url)
        when "POST"
          Net::HTTP::Post.new(url)
        else
          raise Error, "Unsupported invoq API request method."
        end
      end
      private_class_method :build_request

      def self.perform_request(url, request, timeout_ms)
        timeout_seconds = timeout_ms / 1000.0

        Timeout.timeout(timeout_seconds) do
          Net::HTTP.start(
            url.host,
            url.port,
            use_ssl: url.scheme == "https",
            open_timeout: timeout_seconds,
            read_timeout: timeout_seconds,
            write_timeout: timeout_seconds
          ) do |http|
            http.request(request)
          end
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
        raise Error, "invoq API request timed out."
      rescue Error
        raise
      rescue StandardError
        raise Error, "Failed to connect to invoq API."
      end
      private_class_method :perform_request

      def self.api_error_from_response(status, payload)
        error = payload.is_a?(Hash) ? payload : nil
        code = error && error["code"].is_a?(String) ? error["code"] : nil
        message = error && error["message"].is_a?(String) ? error["message"] : "invoq API request failed."
        fields = parse_fields(error && error["fields"])
        meta = error && error["meta"].is_a?(Hash) ? error["meta"] : nil

        ApiError.new(
          message,
          status: status,
          code: code,
          fields: fields,
          meta: meta,
          payload: payload
        )
      end
      private_class_method :api_error_from_response

      def self.parse_fields(value)
        return nil unless value.is_a?(Array)

        fields = value.each_with_object([]) do |field, result|
          next unless field.is_a?(Hash)

          location = field["location"]
          next unless %w[query path body header].include?(location)
          next unless field["field"].is_a?(String)
          next unless field["code"].is_a?(String)
          next unless field["message"].is_a?(String)

          result << {
            "field" => field["field"],
            "location" => location,
            "code" => field["code"],
            "message" => field["message"]
          }
        end

        fields
      end
      private_class_method :parse_fields
    end
  end
end
