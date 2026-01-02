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
end
