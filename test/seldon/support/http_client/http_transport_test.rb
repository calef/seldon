# frozen_string_literal: true

require_relative '../../../test_helper'
require_relative 'test_helpers'

module Seldon
  module Support
    class HttpClient
      class HttpTransportTest < Minitest::Test
        class FakeDelayManager
          def apply_delay(*); end
        end

        def setup
          @transport = HttpTransport.new(
            operation_delay_manager: FakeDelayManager.new,
            user_agent: 'TestAgent/1.0',
            open_timeout: 5,
            read_timeout: 7,
            allow_insecure_fallback: false
          )
        end

        def test_perform_request_get_applies_headers_and_returns_response
          request = HttpClientTestHelpers::FakeRequest.new
          response_value = HttpClientTestHelpers::FakeResponse.new(200)
          connection = Object.new
          connection.define_singleton_method(:get) do |_url, &gb|
            gb.call(request) if gb
            response_value
          end

          @transport.stub(:build_connection, connection) do
            result = @transport.send(
              :perform_request,
              :get,
              URI('https://example.com/path'),
              'text/plain',
              verify: true,
              http_version: :httpv2_0
            )
            assert_equal response_value, result
            assert_equal 'TestAgent/1.0', request.headers['User-Agent']
            assert_equal 'text/plain', request.headers['Accept']
            assert_equal 'identity', request.headers['Accept-Encoding']
          end
        end

        def test_perform_request_head_uses_head_headers
          request = HttpClientTestHelpers::FakeRequest.new
          response_value = HttpClientTestHelpers::FakeResponse.new(100)
          connection = Object.new
          connection.define_singleton_method(:head) do |_url, &gb|
            gb.call(request) if gb
            response_value
          end

          @transport.stub(:build_connection, connection) do
            result = @transport.send(
              :perform_request,
              :head,
              URI('https://example.com'),
              nil,
              verify: true,
              http_version: :httpv2_0
            )
            assert_equal response_value, result
            assert_equal 'TestAgent/1.0', request.headers['User-Agent']
            assert_nil request.headers['Accept']
          end
        end

        def test_perform_request_raises_for_unknown_methods
          connection = Object.new
          connection.define_singleton_method(:get) { } # unused
          @transport.stub(:build_connection, connection) do
            assert_raises(ArgumentError) do
              @transport.send(
                :perform_request,
                :post,
                URI('https://example.com'),
                nil,
                verify: true,
                http_version: :httpv2_0
              )
            end
          end
        end

        def test_build_connection_uses_base_url_and_http_version
          captured = {}
          fake_connection = Object.new

          Faraday.stub(:new, proc { |url:, ssl:, request:, &block|
            captured[:url] = url
            captured[:ssl] = ssl
            captured[:request] = request

            builder = Object.new
            builder.define_singleton_method(:adapter) do |adapter, http_version:|
              captured[:adapter] = adapter
              captured[:http_version] = http_version
            end
            block.call(builder)
            fake_connection
          }) do
            connection = @transport.send(
              :build_connection,
              URI('http://example.com:8080/resource?query=1'),
              verify: false,
              http_version: :httpv1_1
            )
            assert_same fake_connection, connection
            assert_equal 'http://example.com:8080', captured[:url]
            assert_equal({ verify: false }, captured[:ssl])
            assert_equal({ timeout: 7, open_timeout: 5 }, captured[:request])
            assert_equal :typhoeus, captured[:adapter]
            assert_equal :httpv1_1, captured[:http_version]
          end
        end

        def test_base_url_for_includes_port_when_nondefault
          uri = URI('https://example.com:4443/path')
          assert_equal 'https://example.com:4443', @transport.send(:base_url_for, uri)
          assert_equal 'https://example.com', @transport.send(:base_url_for, URI('https://example.com/'))
        end
      end
    end
  end
end
