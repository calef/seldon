# frozen_string_literal: true

require 'faraday'
require 'faraday/typhoeus'
require 'uri'

module Seldon
  module Support
    class HttpClient
      # Handles raw HTTP transport operations (connections, request execution)
      class HttpTransport
        include Seldon::Loggable

        HTTP_VERSIONS = [
          { label: '2', option: 'httpv2_0' },
          { label: '1.1', option: 'httpv1_1' },
          { label: '1.0', option: 'httpv1_0' }
        ].freeze

        def initialize(operation_delay_manager:, user_agent: HttpClient::UA,
                       open_timeout: HttpClient::DEFAULTS[:timeout],
                       read_timeout: HttpClient::DEFAULTS[:timeout],
                       allow_insecure_fallback: HttpClient::DEFAULTS[:allow_insecure_fallback],
                       cookie_jar: nil,
                       from_email: nil)
          @user_agent = user_agent
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @allow_insecure_fallback = allow_insecure_fallback
          @operation_delay_manager = operation_delay_manager
          @cookie_jar = cookie_jar
          @from_email = from_email
        end

        def execute_get(uri, accept, operation: nil, referer: nil, &)
          @operation_delay_manager.apply_delay(operation, uri)
          response = perform_with_fallbacks(:get, uri, accept, referer:, &)
          store_cookies(uri, response)
          response
        end

        def execute_head(uri, operation: nil)
          @operation_delay_manager.apply_delay(operation, uri)
          response = perform_with_fallbacks(:head, uri, nil)
          store_cookies(uri, response)
          response
        end

        private

        def perform_with_fallbacks(method, uri, accept, referer: nil, &)
          HTTP_VERSIONS.each_with_index do |version, index|
            return perform_request(method, uri, accept, verify: true, http_version: version[:option].to_sym, referer:, &)
          rescue Faraday::SSLError => e
            return retry_without_verification(method, uri, accept, e, http_version: version[:option].to_sym, referer:, &)
          rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
            next_version = HTTP_VERSIONS[index + 1]
            if next_version
              logger.debug(
                "HTTP/#{version[:label]} failed for #{uri} (#{e.class}: #{e.message}), " \
                "retrying with HTTP/#{next_version[:label]}"
              )
              next
            end
            raise
          end
        end

        def perform_request(method, uri, accept, verify:, http_version:, referer: nil, &)
          connection = build_connection(uri, verify: verify, http_version: http_version)
          response = case method
                     when :get
                       connection.get(uri.to_s) do |request|
                         apply_get_headers(request, accept, uri, referer:)
                       end
                     when :head
                       connection.head(uri.to_s) do |request|
                         apply_head_headers(request, uri)
                       end
                     else
                       raise ArgumentError, "Unsupported method #{method}"
                     end
          yield response if block_given?
          response
        end

        def build_connection(uri, verify:, http_version:)
          Faraday.new(
            url: base_url_for(uri),
            ssl: { verify: verify },
            request: request_options
          ) do |builder|
            builder.adapter :typhoeus, http_version: http_version
          end
        end

        def base_url_for(uri)
          default_port = uri.scheme == 'https' ? 443 : 80
          if uri.port && uri.port != default_port
            "#{uri.scheme}://#{uri.host}:#{uri.port}"
          else
            "#{uri.scheme}://#{uri.host}"
          end
        end

        def request_options
          {
            timeout: @read_timeout,
            open_timeout: @open_timeout
          }
        end

        def apply_get_headers(request, accept, uri, referer: nil)
          request.headers['User-Agent'] = @user_agent
          request.headers['Accept'] = accept
          request.headers['Accept-Encoding'] = 'identity'
          request.headers['Referer'] = referer if referer
          request.headers['From'] = @from_email if @from_email
          apply_cookies(request, uri)
        end

        def apply_head_headers(request, uri)
          request.headers['User-Agent'] = @user_agent
          request.headers['From'] = @from_email if @from_email
          apply_cookies(request, uri)
        end

        def apply_cookies(request, uri)
          return unless @cookie_jar

          cookie_header = @cookie_jar.cookie_header_for(uri)
          request.headers['Cookie'] = cookie_header if cookie_header
        end

        def store_cookies(uri, response)
          return unless @cookie_jar && response&.headers

          @cookie_jar.store_from_response(uri, response.headers)
        end

        def retry_without_verification(method, uri, accept, error, http_version:, referer: nil, &)
          return handle_terminal_ssl_error(uri, error) unless @allow_insecure_fallback

          logger.warn "SSL error (#{error.message}), retrying without verification for #{uri}"
          perform_request(method, uri, accept, verify: false, http_version:, referer:, &)
        end

        def handle_terminal_ssl_error(uri, error)
          logger.warn "SSL error for #{uri}: #{error.message}"
          raise error
        end
      end
    end
  end
end
