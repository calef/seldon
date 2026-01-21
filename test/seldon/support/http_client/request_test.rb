# frozen_string_literal: true

require_relative '../../../test_helper'
require 'minitest/autorun'
require_relative 'test_helpers'

module Seldon
  module Support
    class HttpClient
      class RequestTest < Minitest::Test
        include HttpClientTestHelpers

        class FakeDelayManager
          def apply_delay(_operation, _uri); end
        end

        def setup
          @logger = HttpClientTestHelpers::FakeLogger.new
          @transport = Seldon::Support::HttpClient::HttpTransport.new(operation_delay_manager: FakeDelayManager.new
          )
        end

        def test_execute_head_uses_fallback_handler
          called = nil
          @transport.stub(:perform_with_fallbacks, proc { |method, uri, accept| called = [method, uri, accept]; :ok }) do
            result = @transport.execute_head(URI('https://example.com'))
            assert_equal :ok, result
            assert_equal [:head, URI('https://example.com'), nil], called
          end
        end

        def test_execute_request_retries_without_verification
          error = Faraday::SSLError.new('boom')
          called = false
          @transport.stub(:perform_request, proc { |_method, _uri, _accept, **_opts| raise error }) do
            @transport.stub(:retry_without_verification, proc { called = true; [:retry] }) do
              assert_equal [:retry], @transport.execute_get(URI('https://example.com'), 'text/html')
              assert called
            end
          end
        end

        def test_retry_without_verification_logs_and_retries_only_when_allowed
          error = Faraday::SSLError.new('boom')
          called = false
          @transport.stub(:perform_request, proc { |_method, _uri, _accept, **_opts| called = true; [:retried] }) do
            assert_equal [:retried],
                         @transport.send(
                           :retry_without_verification,
                           :get,
                           URI('https://example.com'),
                           'text/html',
                           error,
                           http_version: :httpv2_0
                         )
            assert called
          end

          denial_transport = Seldon::Support::HttpClient::HttpTransport.new(
            allow_insecure_fallback: false,
            operation_delay_manager: FakeDelayManager.new
          )
          assert_raises(Faraday::SSLError) do
            denial_transport.send(
              :retry_without_verification,
              :get,
              URI('https://example.com'),
              'text/html',
              error,
              http_version: :httpv2_0
            )
          end
        end

        def test_apply_get_headers_sets_headers
          request = HttpClientTestHelpers::FakeRequest.new
          uri = URI('https://example.com/path')
          @transport.send(:apply_get_headers, request, 'application/json', uri)

          assert_equal Seldon::Support::HttpClient::UA, request.headers['User-Agent']
          assert_equal 'application/json', request.headers['Accept']
          assert_equal 'identity', request.headers['Accept-Encoding']
          assert_nil request.headers['Referer']
        end

        def test_apply_get_headers_sets_referer_when_provided
          request = HttpClientTestHelpers::FakeRequest.new
          uri = URI('https://example.com/path')
          @transport.send(:apply_get_headers, request, 'application/json', uri, referer: 'https://example.com/page')

          assert_equal 'https://example.com/page', request.headers['Referer']
        end

        def test_apply_head_headers_sets_user_agent
          request = HttpClientTestHelpers::FakeRequest.new
          uri = URI('https://example.com/path')
          @transport.send(:apply_head_headers, request, uri)

          assert_equal Seldon::Support::HttpClient::UA, request.headers['User-Agent']
        end
      end
    end
  end
end
