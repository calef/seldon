# frozen_string_literal: true

module Seldon
  module Support
    class HttpClient
      # Handles reading HTTP response bodies without applying size limits
      class ResponseBodyReader
        def self.read(response)
          encoding = charset_encoding(response)

          return read_streaming(response, encoding) if response.respond_to?(:read_body)

          body = response&.body.to_s
          body = body.dup
          body.force_encoding(encoding)
          body
        end

        def self.read_streaming(response, encoding = Encoding::BINARY)
          body = +''
          response.read_body do |chunk|
            body << chunk
          end
          body.force_encoding(encoding)
          body
        end

        # Extracts a usable Encoding from the response's Content-Type charset.
        # Returns Encoding::BINARY when no charset is present or unrecognized.
        def self.charset_encoding(response)
          content_type = response['Content-Type'] if response.respond_to?(:[])
          return Encoding::BINARY unless content_type

          match = content_type.match(/charset="?([^\s";]+)"?/i)
          return Encoding::BINARY unless match

          Encoding.find(match[1])
        rescue ArgumentError
          Encoding::BINARY
        end

        private_class_method :read_streaming, :charset_encoding
      end
    end
  end
end
