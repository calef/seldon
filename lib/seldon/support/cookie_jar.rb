# frozen_string_literal: true

require 'uri'
require 'time'

module Seldon
  module Support
    # Manages HTTP cookies for a session, handling storage, retrieval,
    # and Set-Cookie header parsing per RFC 6265.
    class CookieJar
      Cookie = Struct.new(:name, :value, :domain, :path, :expires, :secure, :http_only, keyword_init: true)

      def initialize
        @cookies = {} # domain -> path -> name -> Cookie
        @mutex = Mutex.new
      end

      # Extract and store cookies from Set-Cookie header(s)
      def store_from_response(uri, response_headers)
        return unless response_headers

        set_cookies = extract_set_cookie_headers(response_headers)
        @mutex.synchronize do
          set_cookies.each { |header| parse_and_store(uri, header) }
        end
      end

      # Generate Cookie header value for a request
      def cookie_header_for(uri)
        matching = cookies_for(uri)
        return nil if matching.empty?

        matching.map { |c| "#{c.name}=#{c.value}" }.join('; ')
      end

      # Get all cookies matching the URI
      def cookies_for(uri)
        host = uri.host&.downcase
        return [] unless host

        path = uri.path.empty? ? '/' : uri.path
        secure = uri.scheme == 'https'
        now = Time.now

        @mutex.synchronize do
          matching = []
          @cookies.each do |domain, paths|
            next unless domain_matches?(host, domain)

            paths.each do |cookie_path, names|
              next unless path_matches?(path, cookie_path)

              names.each_value do |cookie|
                next if cookie.secure && !secure
                next if cookie.expires && cookie.expires < now

                matching << cookie
              end
            end
          end
          matching
        end
      end

      # Clear all cookies
      def clear
        @mutex.synchronize { @cookies = {} }
      end

      # Clear expired cookies
      def clear_expired
        now = Time.now
        @mutex.synchronize do
          @cookies.each_value do |paths|
            paths.each_value do |names|
              names.delete_if { |_, cookie| cookie.expires && cookie.expires < now }
            end
            paths.delete_if { |_, names| names.empty? }
          end
          @cookies.delete_if { |_, paths| paths.empty? }
        end
      end

      # Check if jar has any cookies
      def empty?
        @mutex.synchronize { @cookies.empty? }
      end

      # Count total cookies
      def size
        @mutex.synchronize do
          @cookies.sum { |_, paths| paths.sum { |_, names| names.size } }
        end
      end

      # Serialize to hash (for persistence)
      def to_h
        @mutex.synchronize do
          result = {}
          @cookies.each do |domain, paths|
            result[domain] = {}
            paths.each do |path, names|
              result[domain][path] = {}
              names.each do |name, cookie|
                result[domain][path][name] = {
                  'value' => cookie.value,
                  'expires' => cookie.expires&.iso8601,
                  'secure' => cookie.secure,
                  'http_only' => cookie.http_only
                }
              end
            end
          end
          result
        end
      end

      # Load from hash (for persistence)
      def load(data)
        return unless data.is_a?(Hash)

        @mutex.synchronize do
          data.each do |domain, paths|
            next unless paths.is_a?(Hash)

            paths.each do |path, names|
              next unless names.is_a?(Hash)

              names.each do |name, attrs|
                next unless attrs.is_a?(Hash)

                store(Cookie.new(
                        name:,
                        value: attrs['value'],
                        domain:,
                        path:,
                        expires: attrs['expires'] ? Time.parse(attrs['expires']) : nil,
                        secure: attrs['secure'] || false,
                        http_only: attrs['http_only'] || false
                      ))
              end
            end
          end
        end
      end

      private

      def extract_set_cookie_headers(headers)
        # Handle both single header and array of headers
        # Also handle case-insensitive header names
        values = headers['Set-Cookie'] || headers['set-cookie'] || []
        values = [values] unless values.is_a?(Array)
        values.compact.reject(&:empty?)
      end

      def parse_and_store(uri, header)
        cookie = parse_set_cookie(uri, header)
        store(cookie) if cookie
      end

      def parse_set_cookie(uri, header)
        return nil if header.to_s.strip.empty?

        parts = header.split(';').map(&:strip)
        return nil if parts.empty?

        # First part is name=value
        name_value = parts.shift
        eq_index = name_value.index('=')
        return nil unless eq_index

        name = name_value[0...eq_index].strip
        value = name_value[(eq_index + 1)..].strip
        return nil if name.empty?

        # Parse attributes
        attrs = parse_cookie_attributes(parts)

        Cookie.new(
          name:,
          value:,
          domain: attrs[:domain] || uri.host&.downcase,
          path: attrs[:path] || default_path(uri),
          expires: attrs[:expires],
          secure: attrs[:secure],
          http_only: attrs[:http_only]
        )
      end

      def parse_cookie_attributes(parts)
        attrs = { domain: nil, path: nil, expires: nil, secure: false, http_only: false }

        parts.each do |part|
          key, val = part.split('=', 2).map { |s| s&.strip }
          case key&.downcase
          when 'domain'
            attrs[:domain] = val&.downcase&.sub(/^\./, '')
          when 'path'
            attrs[:path] = val
          when 'expires'
            attrs[:expires] = parse_cookie_time(val) unless attrs[:expires]
          when 'max-age'
            attrs[:expires] = Time.now + val.to_i if val
          when 'secure'
            attrs[:secure] = true
          when 'httponly'
            attrs[:http_only] = true
          end
        end

        attrs
      end

      def parse_cookie_time(value)
        Time.httpdate(value)
      rescue ArgumentError
        begin
          Time.parse(value)
        rescue ArgumentError
          nil
        end
      end

      def default_path(uri)
        path = uri.path
        return '/' if path.empty? || !path.start_with?('/')

        last_slash = path.rindex('/')
        last_slash&.zero? ? '/' : path[0...last_slash]
      end

      # Caller must hold @mutex
      def store(cookie)
        return unless cookie.domain

        @cookies[cookie.domain] ||= {}
        @cookies[cookie.domain][cookie.path] ||= {}
        @cookies[cookie.domain][cookie.path][cookie.name] = cookie
      end

      def domain_matches?(host, cookie_domain)
        return true if host == cookie_domain

        host.end_with?(".#{cookie_domain}")
      end

      def path_matches?(request_path, cookie_path)
        return true if request_path == cookie_path
        return true if request_path.start_with?("#{cookie_path}/")

        cookie_path == '/'
      end
    end
  end
end
