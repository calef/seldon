# frozen_string_literal: true

require 'time'
require 'uri'

module Seldon
  module Support
    class HttpClient
      # Processes HTTP responses (status codes, headers, error handling)
      class ResponseProcessor
        include Seldon::Loggable

        DEFAULT_TOO_MANY_REQUESTS_DELAY = 60
        DEFAULT_SERVICE_UNAVAILABLE_DELAY = 60

        def initialize(too_many_requests_delay: DEFAULT_TOO_MANY_REQUESTS_DELAY,
                       service_unavailable_delay: DEFAULT_SERVICE_UNAVAILABLE_DELAY)
          @too_many_requests_delay = too_many_requests_delay
          @service_unavailable_delay = service_unavailable_delay
        end

        def check_status?(response, uri, origin_url:, operation:)
          status_code = response.status.to_i

          raise_not_modified(uri, origin_url: origin_url, operation: operation) if status_code == 304
          raise_too_many_requests(response, uri, origin_url: origin_url, operation: operation) if status_code == 429
          raise_service_unavailable(response, uri, origin_url: origin_url, operation: operation) if status_code == 503
          raise ForbiddenError.new(url: uri.to_s, origin_url: origin_url, operation: operation) if status_code == 403
          raise NotFoundError.new(url: uri.to_s, origin_url: origin_url, operation: operation, status: status_code) if status_code == 404

          return true if status_code >= 200 && status_code < 300

          raise HttpError.new(url: uri.to_s, origin_url: origin_url, operation: operation, status: status_code, response: response)
        end

        def redirect?(response)
          status = response.status.to_i
          status >= 300 && status < 400 && status != 304
        end

        def extract_redirect_location(response)
          response.headers['location']
        end

        def parse_retry_after(response, default_delay: @too_many_requests_delay)
          header = response&.headers&.[]('retry-after')
          parsed = parse_retry_after_value(header)
          wait = parsed || default_delay
          wait = default_delay if wait <= 0
          wait
        end

        private

        def raise_not_modified(uri, origin_url:, operation:)
          raise NotModifiedError.new(
            url: uri.to_s,
            origin_url: origin_url,
            operation: operation
          )
        end

        def raise_too_many_requests(response, uri, origin_url:, operation:)
          wait = parse_retry_after(response, default_delay: @too_many_requests_delay)
          raise TooManyRequestsError.new(
            url: uri.to_s,
            retry_after: wait,
            origin_url: origin_url,
            operation: operation
          )
        end

        def raise_service_unavailable(response, uri, origin_url:, operation:)
          wait = parse_retry_after(response, default_delay: @service_unavailable_delay)
          raise ServiceUnavailableError.new(
            url: uri.to_s,
            retry_after: wait,
            origin_url: origin_url,
            operation: operation
          )
        end

        def parse_retry_after_value(value)
          return nil unless value

          if value.match?(/\A\d+\z/)
            value.to_i
          else
            (Time.httpdate(value) - Time.now).ceil
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
