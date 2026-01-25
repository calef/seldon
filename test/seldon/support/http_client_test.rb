# frozen_string_literal: true

require_relative '../../test_helper'
require 'minitest/autorun'

# Integration tests for HttpClient public API
# Unit tests for individual components are in the http_client/ subdirectory
class HttpClientTest < Minitest::Test
  class FakeLogger
    attr_reader :warns, :debugs

    def initialize
      @warns = []
      @debugs = []
    end

    def warn(message)
      @warns << message
    end

    def debug(message)
      @debugs << message
    end

    def info(_message); end
  end

  def setup
    @logger = FakeLogger.new
    Seldon::Logging.logger = @logger
    @client = Seldon::Support::HttpClient.new(delay: 0,
      max_retries: 1,
      timeout: 1,
      open_timeout: 1,
      read_timeout: 1,
      host_operation_delays: {}
    )
    @request_flow = @client.instance_variable_get(:@request_flow)
  end

  def teardown
    Seldon::Logging.reset_logger
  end

  # Public API: resolve_final_url

  def test_resolve_final_url_returns_successful_redirect
    @request_flow.stub(:resolve_head_redirects, { status: 200, url: 'https://final' }) do
      assert_equal 'https://final', @client.resolve_final_url('https://start')
    end
  end

  def test_resolve_final_url_returns_nil_for_non_successful_status
    @request_flow.stub(:resolve_head_redirects, { status: 400, url: 'https://start' }) do
      assert_nil @client.resolve_final_url('https://start')
      assert_match(/Skipping canonical redirect/, @logger.debugs.last)
    end
  end

  def test_resolve_final_url_handles_invalid_uri
    assert_nil @client.resolve_final_url('not valid://')
    assert_match(/Invalid URI/, @logger.debugs.last)
  end

  # Public API: response_for

  def test_response_for_returns_hash_with_status_and_url
    response = Struct.new(:status, :headers)
    payload = { final_url: 'https://example.com' }
    @request_flow.stub(:fetch_with_redirects, [response.new(200, {}), payload]) do
      result = @client.response_for('https://example.com', accept: 'text/plain')
      assert_equal 200, result[:status]
      assert_equal 'https://example.com', result[:final_url]
    end
  end

  def test_response_for_handles_invalid_uri
    assert_nil @client.response_for('not valid://')
    assert_match(/Invalid URI while checking status/, @logger.debugs.last)
  end

  def test_response_for_handles_not_found_error
    error = Seldon::Support::HttpClient::NotFoundError.new(
      url: 'https://example.com',
      origin_url: 'https://example.com',
      operation: 'status_check',
      status: 404
    )
    @request_flow.stub(:fetch_with_redirects, proc { raise error }) do
      result = @client.response_for('https://example.com')
      assert_equal 404, result[:status]
      assert_equal 'https://example.com', result[:final_url]
      assert_nil result[:response]
    end
  end

  def test_response_for_handles_forbidden_error
    error = Seldon::Support::HttpClient::ForbiddenError.new(
      url: 'https://example.com',
      origin_url: 'https://example.com',
      operation: 'status_check'
    )
    @request_flow.stub(:fetch_with_redirects, proc { raise error }) do
      result = @client.response_for('https://example.com')
      assert_equal 403, result[:status]
      assert_equal 'https://example.com', result[:final_url]
      assert_nil result[:response]
    end
  end

  def test_fetch_does_not_retry_forbidden_error
    error = Seldon::Support::HttpClient::ForbiddenError.new(
      url: 'https://example.com',
      origin_url: 'https://example.com',
      operation: 'content_fetch'
    )
    
    call_count = 0
    @request_flow.stub(:fetch_with_redirects, proc do
      call_count += 1
      raise error
    end) do
      assert_raises(Seldon::Support::HttpClient::ForbiddenError) do
        @client.fetch('https://example.com', accept: 'text/html')
      end
      assert_equal 1, call_count, 'Forbidden error should not be retried'
    end
  end

  # Public API: fetch

  def test_fetch_returns_payload_body
    payload = {
      body: 'test content',
      content_type: 'text/html',
      final_url: 'https://example.com'
    }
    response = Struct.new(:status, :headers)
    @request_flow.stub(:fetch_with_redirects, [response.new(200, {}), payload]) do
      result = @client.fetch('https://example.com', accept: 'text/html')
      assert_equal payload, result
    end
  end

  def test_fetch_retries_on_too_many_requests
    error = Seldon::Support::HttpClient::TooManyRequestsError.new(
      url: 'https://example.com',
      retry_after: 0.01,
      origin_url: 'https://example.com',
      operation: 'content_fetch'
    )
    
    call_count = 0
    payload = { body: 'success', content_type: 'text/html', final_url: 'https://example.com' }
    response = Struct.new(:status, :headers)
    
    @request_flow.stub(:fetch_with_redirects, proc do
      call_count += 1
      raise error if call_count == 1
      [response.new(200, {}), payload]
    end) do
      result = @client.fetch('https://example.com', accept: 'text/html')
      assert_equal payload, result
      assert_equal 2, call_count
    end
  end

  def test_fetch_raises_after_max_retries
    error = Seldon::Support::HttpClient::TooManyRequestsError.new(
      url: 'https://example.com',
      retry_after: 0.01,
      origin_url: 'https://example.com',
      operation: 'content_fetch'
    )

    @request_flow.stub(:fetch_with_redirects, proc { raise error }) do
      assert_raises(Seldon::Support::HttpClient::TooManyRequestsError) do
        @client.fetch('https://example.com', accept: 'text/html')
      end
    end
  end

  def test_retry_after_is_capped_to_max_delay
    # Test that ResponseProcessor caps the retry-after value
    processor = Seldon::Support::HttpClient::ResponseProcessor.new(
      max_retry_after_delay: 60
    )

    # Mock response with a very long Retry-After header (1 hour)
    response = Struct.new(:headers).new({ 'retry-after' => '3600' })
    wait = processor.parse_retry_after(response, default_delay: 30)

    # Should be capped to max_retry_after_delay (60), not the header value (3600)
    assert_equal 60, wait
  end

  def test_retry_after_respects_header_when_under_max
    processor = Seldon::Support::HttpClient::ResponseProcessor.new(
      max_retry_after_delay: 300
    )

    # Mock response with a reasonable Retry-After header
    response = Struct.new(:headers).new({ 'retry-after' => '120' })
    wait = processor.parse_retry_after(response, default_delay: 30)

    # Should use the header value since it's under the max
    assert_equal 120, wait
  end

  def test_retry_after_uses_default_when_no_header
    processor = Seldon::Support::HttpClient::ResponseProcessor.new(
      max_retry_after_delay: 300
    )

    response = Struct.new(:headers).new({})
    wait = processor.parse_retry_after(response, default_delay: 30)

    # Should use the default since no header is present
    assert_equal 30, wait
  end
end
