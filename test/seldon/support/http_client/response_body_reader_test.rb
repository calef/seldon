# frozen_string_literal: true

require_relative '../../../test_helper'
require 'minitest/autorun'
require_relative 'test_helpers'

module Seldon
  module Support
    class HttpClient
      class ResponseBodyReaderTest < Minitest::Test
        include HttpClientTestHelpers

        def test_read_response_body_returns_full_body
          response = HttpClientTestHelpers::FakeResponse.new(200, {}, body: 'Hello World')
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello World', body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_response_body_handles_multibyte_characters
          # UTF-8 multibyte character: € is 3 bytes (E2 82 AC)
          response = HttpClientTestHelpers::FakeResponse.new(200, {}, body: 'Hello €50')
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          expected = 'Hello €50'.dup.force_encoding('BINARY')

          assert_equal expected, body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_response_body_reads_streaming_responses
          response = HttpClientTestHelpers::FakeResponseStream.new(['Hello', ' ', 'World'])
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello World', body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_response_body_uses_binary_encoding
          response = HttpClientTestHelpers::FakeResponse.new(200, {}, body: 'test')
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_response_body_handles_empty_response
          response = HttpClientTestHelpers::FakeResponse.new(200, {}, body: nil)
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal '', body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_uses_utf8_when_charset_specified
          response = HttpClientTestHelpers::FakeResponse.new(
            200, { 'Content-Type' => 'text/html; charset=utf-8' }, body: 'Hello'
          )
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello', body
          assert_equal Encoding::UTF_8, body.encoding
        end

        def test_read_uses_binary_when_no_content_type
          response = HttpClientTestHelpers::FakeResponse.new(200, {}, body: 'Hello')
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello', body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_uses_binary_for_unknown_charset
          response = HttpClientTestHelpers::FakeResponse.new(
            200, { 'Content-Type' => 'text/html; charset=made-up-encoding' }, body: 'Hello'
          )
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello', body
          assert_equal Encoding::BINARY, body.encoding
        end

        def test_read_uses_iso_8859_1_when_charset_specified
          response = HttpClientTestHelpers::FakeResponse.new(
            200, { 'Content-Type' => 'text/html; charset=iso-8859-1' }, body: 'Hello'
          )
          body = Seldon::Support::HttpClient::ResponseBodyReader.read(response)

          assert_equal 'Hello', body
          assert_equal Encoding::ISO_8859_1, body.encoding
        end
      end
    end
  end
end
