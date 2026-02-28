# frozen_string_literal: true

require_relative '../../test_helper'
require 'minitest/autorun'

class UrlNormalizerTest < Minitest::Test
  def test_absolute_and_protocol_relative
    assert_equal 'https://example.com/foo', Seldon::Support::UrlNormalizer.normalize('https://example.com/foo')
    assert_equal 'https://example.com/foo', Seldon::Support::UrlNormalizer.normalize('//example.com/foo')
  end

  def test_missing_host_with_base
    base = 'https://example.com/blog/'

    assert_equal 'https://example.com/posts/1', Seldon::Support::UrlNormalizer.normalize('/posts/1', base: base)
    assert_equal 'https://example.com/blog/posts/1', Seldon::Support::UrlNormalizer.normalize('posts/1', base: base)
  end

  def test_invalid_urls_return_nil
    assert_nil Seldon::Support::UrlNormalizer.normalize('javascript:alert(1)')
    assert_nil Seldon::Support::UrlNormalizer.normalize('not a url')
  end

  def test_filtered_query_removes_tracking_parameters
    uri = URI('https://example.com/?utm_source=x&foo=bar&fbclid=123')
    filtered = Seldon::Support::UrlNormalizer.send(:filtered_query, uri)

    assert_equal 'foo=bar', filtered
  end

  def test_filtered_query_preserves_non_tracking_params
    uri = URI('https://example.com/?fc=a&foo=b')
    filtered = Seldon::Support::UrlNormalizer.send(:filtered_query, uri)

    assert_equal 'fc=a&foo=b', filtered
  end

  def test_filtered_query_returns_nil_when_only_tracking_params
    uri = URI('https://example.com/?utm_source=x&fbclid=1')
    assert_nil Seldon::Support::UrlNormalizer.send(:filtered_query, uri)
  end

  def test_filtered_query_returns_original_when_decode_fails
    original_query = 'broken=%E0%a'
    uri = URI("https://example.com/?#{original_query}")

    Seldon::Support::UrlNormalizer.stub(:decode_query, nil) do
      result = Seldon::Support::UrlNormalizer.send(:filtered_query, uri)
      assert_equal original_query, result
    end
  end

  def test_decode_query_handles_invalid_encoding
    URI.stub(:decode_www_form, proc { |_query, _encoding| raise ArgumentError }) do
      assert_nil Seldon::Support::UrlNormalizer.send(:decode_query, '%E0%a=bad')
    end

    assert_equal [['foo', 'bar']], Seldon::Support::UrlNormalizer.send(:decode_query, 'foo=bar')
  end

  def test_tracking_prefix_detection
    assert Seldon::Support::UrlNormalizer.send(:tracking_prefix?, 'utm_source')
    refute Seldon::Support::UrlNormalizer.send(:tracking_prefix?, 'foo')
  end
end
