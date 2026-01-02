# frozen_string_literal: true

require 'uri'

require_relative 'http_client'
require_relative '../logging'

module Seldon
  module Support
    class HttpStatusResolver
      include Seldon::Loggable

      MAX_REDIRECTS = 5
      DEFAULT_TIMEOUT = 10

      def initialize(
        user_agent: Seldon::Support::HttpClient::UA,
        http_client: nil,
        max_redirects: MAX_REDIRECTS,
        open_timeout: DEFAULT_TIMEOUT,
        read_timeout: DEFAULT_TIMEOUT
      )
        @max_redirects = max_redirects
        @http_client = http_client || Seldon::Support::HttpClient.new(
          user_agent: user_agent,
          max_redirects: max_redirects,
          open_timeout: open_timeout,
          read_timeout: read_timeout
        )
      end

      def call(url)
        resolve(url)
      end

      private

      def resolve(url)
        uri = URI.parse(url)
        return :error unless %w[http https].include?(uri.scheme)

        status_result = request_status(url)
        return :error unless status_result

        status = status_result[:status]
        case status
        when 200..299
          :success
        when 404, 410
          :not_found
        else
          logger.debug "URL #{url} returned status #{status}" if status
          :error
        end
      rescue StandardError => e
        logger.debug "Exception resolving URL #{url}: #{e.class}: #{e.message}"
        :error
      end

      def request_status(url)
        @http_client.response_for(url, accept: Seldon::Support::HttpClient::HTML_ACCEPT)
      rescue StandardError => e
        logger.debug "Failed to fetch #{url}: #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
