# frozen_string_literal: true

require_relative '../../../test_helper'
require 'minitest/autorun'
require_relative 'test_helpers'

module Seldon
  module Support
    class HttpClient
      class RequestFlowTest < Minitest::Test
        include HttpClientTestHelpers

        def setup
          @response_processor = Seldon::Support::HttpClient::ResponseProcessor.new
        end

        def build_request_flow(transport = nil, max_redirects: 3)
          Seldon::Support::HttpClient::RequestFlow.new(
            transport: transport,
            response_processor: @response_processor,
            max_redirects: max_redirects
          )
        end

        def test_extract_headers_returns_hash_when_to_h_available
          request_flow = build_request_flow
          headers = { 'content-type' => 'application/json' }

          assert_equal headers, request_flow.send(:extract_headers, headers)
        end

        def test_extract_headers_returns_empty_hash_for_nil
          request_flow = build_request_flow

          assert_equal({}, request_flow.send(:extract_headers, nil))
        end

        def test_extract_headers_returns_empty_hash_without_to_h
          request_flow = build_request_flow

          assert_equal({}, request_flow.send(:extract_headers, Object.new))
        end

        def test_extract_headers_returns_empty_hash_when_to_h_raises
          request_flow = build_request_flow
          headers = Class.new do
            def to_h
              raise StandardError, 'broken'
            end
          end.new

          assert_equal({}, request_flow.send(:extract_headers, headers))
        end
      end
    end
  end
end
