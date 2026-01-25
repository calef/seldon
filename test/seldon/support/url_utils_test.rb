# frozen_string_literal: true

require_relative '../../test_helper'
require 'minitest/autorun'

class UrlUtilsTest < Minitest::Test
  def test_absolutize_and_parse_host
    base = 'https://example.com/path/'

    assert_equal 'https://example.com/foo', Seldon::Support::UrlUtils.absolutize(base, '/foo')
    assert_equal 'example.com', Seldon::Support::UrlUtils.parse_host(base)
  end

  def test_enforce_https_and_non_feed
    base = 'https://example.com'
    http = 'http://example.com/feed.xml'
    https = Seldon::Support::UrlUtils.enforce_https(base, http)

    assert_equal 'https://example.com/feed.xml', https
    assert Seldon::Support::UrlUtils.non_feed_url?('https://example.com/file.pdf')
  end

  def test_base_url_for_returns_scheme_and_host
    assert_equal 'https://example.com', Seldon::Support::UrlUtils.base_url_for('https://example.com/page')
  end

  def test_base_url_for_preserves_non_default_port
    assert_equal 'https://example.com:8443', Seldon::Support::UrlUtils.base_url_for('https://example.com:8443/foo')
  end

  def test_base_url_for_omits_default_https_port
    assert_equal 'https://example.com', Seldon::Support::UrlUtils.base_url_for('https://example.com:443/page')
  end

  def test_base_url_for_omits_default_http_port
    assert_equal 'http://example.com', Seldon::Support::UrlUtils.base_url_for('http://example.com:80/page')
  end

  def test_base_url_for_strips_path_and_query
    assert_equal 'https://example.com', Seldon::Support::UrlUtils.base_url_for('https://example.com/path?query=1#fragment')
  end

  def test_base_url_for_returns_nil_for_invalid_url
    assert_nil Seldon::Support::UrlUtils.base_url_for('not a url')
  end

  def test_base_url_for_returns_nil_for_nil
    assert_nil Seldon::Support::UrlUtils.base_url_for(nil)
  end

  def test_base_url_for_returns_nil_for_empty_string
    assert_nil Seldon::Support::UrlUtils.base_url_for('')
  end

  def test_base_url_for_handles_subdomain
    assert_equal 'https://www.example.com', Seldon::Support::UrlUtils.base_url_for('https://www.example.com/page')
  end

  def test_base_url_for_handles_ipv6_with_port
    assert_equal 'http://[::1]:3000', Seldon::Support::UrlUtils.base_url_for('http://[::1]:3000/foo')
  end

  def test_base_url_for_handles_ipv6_default_port
    assert_equal 'http://[::1]', Seldon::Support::UrlUtils.base_url_for('http://[::1]:80/foo')
  end
end
