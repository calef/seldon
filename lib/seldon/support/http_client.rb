# frozen_string_literal: true

require 'uri'
require 'faraday'
require 'faraday/typhoeus'
require 'seldon/logging'
require_relative 'env_utils'
require_relative 'url_utils'
require_relative 'http_client/response_body_reader'
require_relative 'http_client/http_transport'
require_relative 'http_client/response_processor'
require_relative 'http_client/request_flow'
require_relative 'http_client/operation_delay_manager'
require_relative 'cookie_jar'

module Seldon
  module Support
    class HttpClient
      include Seldon::Loggable

      UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/537.36 ' \
           '(KHTML, like Gecko) Chrome/125.0 Safari/537.36'
      HTML_ACCEPT = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'

      DEFAULTS = {
        delay: 0.15,
        max_redirects: 5,
        timeout: 30,
        allow_insecure_fallback: true,
        max_retries: 3,
        retry_initial_delay: 0.5,
        retry_backoff_factor: 2.0,
        retry_jitter: 0.25,
        too_many_requests_delay: 60,
        service_unavailable_delay: 60,
        max_retry_after_delay: 300
      }.freeze

      RETRYABLE_ERRORS = [
        Faraday::ConnectionFailed,
        Faraday::TimeoutError,
        SocketError,
        Timeout::Error,
        EOFError,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Errno::ETIMEDOUT
      ].freeze

      class TooManyRequestsError < StandardError
        attr_reader :retry_after, :url, :origin_url, :operation

        def initialize(url:, retry_after:, origin_url:, operation:)
          super("HTTP 429 Too Many Requests for #{url}")
          @url = url
          @retry_after = retry_after
          @origin_url = origin_url
          @operation = operation
        end
      end

      class ServiceUnavailableError < StandardError
        attr_reader :retry_after, :url, :origin_url, :operation

        def initialize(url:, retry_after:, origin_url:, operation:)
          super("HTTP 503 Service Unavailable for #{url}")
          @url = url
          @retry_after = retry_after
          @origin_url = origin_url
          @operation = operation
        end
      end

      class NotFoundError < StandardError
        attr_reader :url, :origin_url, :operation, :status

        def initialize(url:, origin_url:, operation:, status: 404)
          super("HTTP #{status} for #{url}")
          @url = url
          @origin_url = origin_url
          @operation = operation
          @status = status
        end
      end

      class ForbiddenError < StandardError
        attr_reader :url, :origin_url, :operation, :status

        def initialize(url:, origin_url:, operation:, status: 403)
          super("HTTP #{status} for #{url}")
          @url = url
          @origin_url = origin_url
          @operation = operation
          @status = status
        end
      end

      class HttpError < StandardError
        attr_reader :url, :origin_url, :operation, :status, :response

        def initialize(url:, origin_url:, operation:, status:, response: nil)
          super("HTTP #{status} for #{url}")
          @url = url
          @origin_url = origin_url
          @operation = operation
          @status = status
          @response = response
        end
      end

      class NotModifiedError < StandardError
        attr_reader :url, :origin_url, :operation

        def initialize(url:, origin_url:, operation:)
          super("HTTP 304 Not Modified for #{url}")
          @url = url
          @origin_url = origin_url
          @operation = operation
        end
      end

      def initialize(user_agent: UA, delay: DEFAULTS[:delay], max_redirects: DEFAULTS[:max_redirects],
                     timeout: nil, open_timeout: nil, read_timeout: nil,
                     max_retries: DEFAULTS[:max_retries],
                     retry_initial_delay: DEFAULTS[:retry_initial_delay],
                     retry_backoff_factor: DEFAULTS[:retry_backoff_factor],
                     retry_jitter: DEFAULTS[:retry_jitter],
                     allow_insecure_fallback: DEFAULTS[:allow_insecure_fallback],
                     too_many_requests_delay: DEFAULTS[:too_many_requests_delay],
                     service_unavailable_delay: DEFAULTS[:service_unavailable_delay],
                     max_retry_after_delay: DEFAULTS[:max_retry_after_delay],
                     host_operation_delays: nil,
                     cookie_jar: nil,
                     from_email: nil,
                     accept_language: nil)
        @user_agent = user_agent
        @delay = delay
        @max_redirects = max_redirects
        base_timeout = timeout || DEFAULTS[:timeout]
        @open_timeout = open_timeout || base_timeout
        @read_timeout = read_timeout || base_timeout
        @allow_insecure_fallback = allow_insecure_fallback
        @max_retries = [max_retries.to_i, 1].max
        @retry_initial_delay = retry_initial_delay
        @retry_backoff_factor = retry_backoff_factor
        @retry_jitter = retry_jitter
        @too_many_requests_delay = too_many_requests_delay
        @service_unavailable_delay = service_unavailable_delay
        @max_retry_after_delay = max_retry_after_delay

        @operation_delay_manager = OperationDelayManager.new(host_operation_delays: host_operation_delays)
        @transport = HttpTransport.new(
          user_agent: @user_agent,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          allow_insecure_fallback: @allow_insecure_fallback,
          operation_delay_manager: @operation_delay_manager,
          cookie_jar: cookie_jar,
          from_email: from_email,
          accept_language: accept_language
        )
        @response_processor = ResponseProcessor.new(
          too_many_requests_delay: @too_many_requests_delay,
          service_unavailable_delay: @service_unavailable_delay,
          max_retry_after_delay: @max_retry_after_delay
        )
        @request_flow = RequestFlow.new(
          transport: @transport,
          response_processor: @response_processor,
          max_redirects: @max_redirects
        )
      end

      def fetch(url, accept:, referer: nil, if_modified_since: nil, if_none_match: nil)
        payload = nil
        with_retries(url) do
          _response, payload = @request_flow.fetch_with_redirects(
            url,
            accept,
            origin_url: url,
            operation: 'content_fetch',
            referer:,
            if_modified_since:,
            if_none_match:
          )
          sleep @delay
        rescue NotModifiedError
          sleep @delay
          return { not_modified: true, final_url: url }
        rescue ForbiddenError
          logger.warn "Access forbidden (HTTP 403) for #{url}, not retrying"
          raise
        end
        payload
      end

      def resolve_final_url(url)
        with_retries(url) do
          uri = URI.parse(url)
          result = @request_flow.resolve_head_redirects(uri, origin_url: url, operation: 'canonical_head')
          return unless result

          status = result[:status]
          return result[:url] if status && status >= 200 && status < 300

          logger.debug "Skipping canonical redirect for #{url} due to status #{status}" if status
          nil
        rescue ForbiddenError
          logger.debug "Access forbidden (HTTP 403) for #{url}, not retrying"
          return nil
        rescue URI::InvalidURIError => e
          logger.debug "Invalid URI for canonical resolution (#{url}): #{e.message}"
          return nil
        rescue StandardError => e
          logger.debug "Failed to resolve canonical URL for #{url}: #{e.message}"
          return nil
        end
      end

      def response_for(url, accept: HTML_ACCEPT, referer: nil)
        with_retries(url, return_on_exhaust: true) do
          response, payload = @request_flow.fetch_with_redirects(
            url,
            accept,
            origin_url: url,
            operation: 'status_check',
            referer:
          )
          return {
            status: response.status.to_i,
            final_url: payload[:final_url],
            response: response
          }
        rescue ForbiddenError => e
          logger.debug "Access forbidden (HTTP 403) for #{url}, not retrying"
          return {
            status: 403,
            final_url: e.url || url,
            response: nil
          }
        rescue NotFoundError => e
          return {
            status: e.status || 404,
            final_url: e.url || url,
            response: nil
          }
        rescue URI::InvalidURIError => e
          logger.debug "Invalid URI while checking status (#{url}): #{e.message}"
          return nil
        rescue StandardError => e
          logger.debug "Failed to check status for #{url}: #{e.message}"
          return nil
        end
      end

      private

      # Unified retry loop for all public methods.
      # Handles TooManyRequestsError, ServiceUnavailableError, and RETRYABLE_ERRORS
      # with exponential backoff and jitter. Non-retryable errors (ForbiddenError, etc.)
      # should be handled inside the block.
      #
      # When return_on_exhaust is true, returns nil after max retries instead of raising.
      def with_retries(url, return_on_exhaust: false)
        attempt = 0
        max_attempts = @max_retries + 1
        begin
          attempt += 1
          yield
        rescue TooManyRequestsError => e
          if attempt > @max_retries
            return log_exhaustion(url, max_attempts, 'HTTP 429 Too Many Requests') if return_on_exhaust

            raise
          end

          wait = apply_jitter(e.retry_after || @too_many_requests_delay)
          log_rate_limit_backoff(e, wait, status: 429, attempt: attempt, max_attempts: max_attempts)
          sleep wait
          retry
        rescue ServiceUnavailableError => e
          if attempt > @max_retries
            return log_exhaustion(url, max_attempts, 'HTTP 503 Service Unavailable') if return_on_exhaust

            raise
          end

          wait = apply_jitter(e.retry_after || @service_unavailable_delay)
          log_rate_limit_backoff(e, wait, status: 503, attempt: attempt, max_attempts: max_attempts)
          sleep wait
          retry
        rescue *RETRYABLE_ERRORS => e
          if attempt > @max_retries
            return log_exhaustion(url, max_attempts, "#{e.class} (#{e.message})") if return_on_exhaust

            raise
          end

          wait = apply_jitter(@retry_initial_delay * (@retry_backoff_factor**(attempt - 1)))
          logger.debug(
            "Retrying #{url} after #{e.class} (#{e.message}) in #{format('%.2f', wait)}s " \
            "(attempt #{attempt}/#{max_attempts})"
          )
          sleep wait
          retry
        end
      end

      def apply_jitter(base_wait)
        return base_wait if @retry_jitter.nil? || @retry_jitter <= 0

        jitter_range = base_wait * @retry_jitter
        [base_wait + rand(-jitter_range..jitter_range), 0].max
      end

      def log_exhaustion(url, max_attempts, reason)
        logger.warn("Failed for #{url} after #{max_attempts} attempts: #{reason}")
        nil
      end

      def log_rate_limit_backoff(error, wait, status:, attempt:, max_attempts:)
        operation = error.operation || 'unknown'
        origin = error.origin_url || 'unknown'
        request = error.url || 'unknown'
        logger.warn(
          "Backoff after #{status} during #{operation} " \
          "(origin=#{origin}, request=#{request}) for #{format('%.2f', wait)}s " \
          "(attempt #{attempt}/#{max_attempts})"
        )
      end
    end
  end
end
