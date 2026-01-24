# frozen_string_literal: true

require 'uri'
require_relative 'url_normalizer'

module Seldon
  module Support
    module UrlUtils
      NON_FEED_URL_PATTERNS = [
        /\.(pdf|docx?|xlsx?|pptx?|zip)(\?|$)/i,
        %r{DocumentCenter/(View|Download)/}i
      ].freeze

      module_function

      def absolutize(base_url, href)
        return nil if href.nil?

        cleaned = href.strip
        return nil if cleaned.empty? || cleaned.start_with?('#')

        downcased = cleaned.downcase
        return nil if downcased.start_with?('javascript:', 'data:', 'mailto:')

        base = URI.parse(base_url)
        URI.join(base, cleaned).to_s
      rescue URI::Error
        nil
      end

      def parse_host(url)
        URI.parse(url).host
      rescue URI::Error
        nil
      end

      def enforce_https(base_url, candidate_url)
        return candidate_url unless candidate_url&.match?(%r{\Ahttps?://})
        return candidate_url if candidate_url.start_with?('https://')

        return candidate_url unless base_url&.start_with?('https://')

        candidate_host = parse_host(candidate_url)
        base_host = parse_host(base_url)
        return candidate_url unless candidate_host && base_host && candidate_host == base_host

        candidate_url.sub(/\Ahttp:/, 'https:')
      end

      def non_feed_url?(url)
        return false unless url

        NON_FEED_URL_PATTERNS.any? { |pattern| url.match?(pattern) }
      end

      # Extract the base URL (scheme + host + optional non-default port) from a URL.
      # Returns nil if the URL is invalid or missing required components.
      def base_url_for(url)
        normalized = UrlNormalizer.normalize(url)
        return nil unless normalized

        uri = URI.parse(normalized)
        return nil unless uri.scheme && uri.host

        base = "#{uri.scheme}://#{uri.host}"
        base += ":#{uri.port}" if uri.port && uri.port != uri.default_port
        base
      rescue URI::Error
        nil
      end
    end
  end
end
