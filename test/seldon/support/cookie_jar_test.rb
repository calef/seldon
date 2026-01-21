# frozen_string_literal: true

require_relative '../../test_helper'

class CookieJarTest < Minitest::Test
  def setup
    @jar = Seldon::Support::CookieJar.new
  end

  def test_new_jar_is_empty
    assert_empty @jar
    assert_equal 0, @jar.size
  end

  def test_store_from_response_parses_simple_cookie
    uri = URI.parse('https://example.com/path')
    headers = { 'Set-Cookie' => 'session=abc123' }

    @jar.store_from_response(uri, headers)

    assert_equal 1, @jar.size
    assert_equal 'session=abc123', @jar.cookie_header_for(uri)
  end

  def test_store_from_response_parses_cookie_with_attributes
    uri = URI.parse('https://example.com/app')
    headers = { 'Set-Cookie' => 'token=xyz; Path=/app; Secure; HttpOnly' }

    @jar.store_from_response(uri, headers)

    assert_equal 1, @jar.size
    assert_equal 'token=xyz', @jar.cookie_header_for(uri)
  end

  def test_store_from_response_parses_multiple_cookies
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => ['session=abc', 'user=john'] }

    @jar.store_from_response(uri, headers)

    assert_equal 2, @jar.size
    header = @jar.cookie_header_for(uri)

    assert_includes header, 'session=abc'
    assert_includes header, 'user=john'
  end

  def test_store_from_response_handles_case_insensitive_header_name
    uri = URI.parse('https://example.com/')
    headers = { 'set-cookie' => 'session=abc' }

    @jar.store_from_response(uri, headers)

    assert_equal 1, @jar.size
    assert_equal 'session=abc', @jar.cookie_header_for(uri)
  end

  def test_cookie_header_for_returns_nil_when_no_matching_cookies
    uri = URI.parse('https://example.com/')

    assert_nil @jar.cookie_header_for(uri)
  end

  def test_domain_matching_exact
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Domain=example.com' }
    @jar.store_from_response(uri, headers)

    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/'))
  end

  def test_domain_matching_subdomain
    uri = URI.parse('https://www.example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Domain=example.com' }
    @jar.store_from_response(uri, headers)

    # Cookie set for example.com should match www.example.com
    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://www.example.com/'))
    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/'))
  end

  def test_domain_matching_no_cross_domain
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Domain=example.com' }
    @jar.store_from_response(uri, headers)

    # Different domain should not match
    assert_nil @jar.cookie_header_for(URI.parse('https://other.com/'))
  end

  def test_path_matching_exact
    uri = URI.parse('https://example.com/app')
    headers = { 'Set-Cookie' => 'session=abc; Path=/app' }
    @jar.store_from_response(uri, headers)

    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/app'))
    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/app/page'))
  end

  def test_path_matching_does_not_match_other_paths
    uri = URI.parse('https://example.com/app')
    headers = { 'Set-Cookie' => 'session=abc; Path=/app' }
    @jar.store_from_response(uri, headers)

    assert_nil @jar.cookie_header_for(URI.parse('https://example.com/other'))
  end

  def test_path_matching_root_matches_all
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Path=/' }
    @jar.store_from_response(uri, headers)

    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/any/path'))
  end

  def test_secure_cookie_only_sent_over_https
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Secure' }
    @jar.store_from_response(uri, headers)

    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/'))
    assert_nil @jar.cookie_header_for(URI.parse('http://example.com/'))
  end

  def test_expired_cookie_not_returned
    uri = URI.parse('https://example.com/')
    past = (Time.now - 3600).httpdate
    headers = { 'Set-Cookie' => "session=abc; Expires=#{past}" }
    @jar.store_from_response(uri, headers)

    assert_nil @jar.cookie_header_for(uri)
  end

  def test_max_age_calculates_expiration
    uri = URI.parse('https://example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Max-Age=3600' }
    @jar.store_from_response(uri, headers)

    assert_equal 'session=abc', @jar.cookie_header_for(uri)
  end

  def test_cookie_update_replaces_existing
    uri = URI.parse('https://example.com/')

    @jar.store_from_response(uri, { 'Set-Cookie' => 'session=first' })

    assert_equal 'session=first', @jar.cookie_header_for(uri)

    @jar.store_from_response(uri, { 'Set-Cookie' => 'session=second' })

    assert_equal 'session=second', @jar.cookie_header_for(uri)
    assert_equal 1, @jar.size
  end

  def test_clear_removes_all_cookies
    uri = URI.parse('https://example.com/')
    @jar.store_from_response(uri, { 'Set-Cookie' => ['a=1', 'b=2'] })

    assert_equal 2, @jar.size
    @jar.clear

    assert_empty @jar
  end

  def test_clear_expired_removes_only_expired
    uri = URI.parse('https://example.com/')
    future = (Time.now + 3600).httpdate
    past = (Time.now - 3600).httpdate

    @jar.store_from_response(uri, { 'Set-Cookie' => [
                               "keep=value; Expires=#{future}",
                               "remove=value; Expires=#{past}"
                             ] })

    @jar.clear_expired

    assert_equal 1, @jar.size
    assert_equal 'keep=value', @jar.cookie_header_for(uri)
  end

  def test_to_h_serializes_cookies
    uri = URI.parse('https://example.com/')
    @jar.store_from_response(uri, { 'Set-Cookie' => 'session=abc; Secure' })

    hash = @jar.to_h

    assert hash.key?('example.com')
    assert_equal 'abc', hash['example.com']['/']['session']['value']
    assert hash['example.com']['/']['session']['secure']
  end

  def test_load_restores_cookies
    uri = URI.parse('https://example.com/')
    data = {
      'example.com' => {
        '/' => {
          'session' => {
            'value' => 'restored',
            'secure' => false,
            'http_only' => false
          }
        }
      }
    }

    @jar.load(data)

    assert_equal 'session=restored', @jar.cookie_header_for(uri)
  end

  def test_load_with_expiration
    uri = URI.parse('https://example.com/')
    future = (Time.now + 3600).iso8601
    data = {
      'example.com' => {
        '/' => {
          'session' => {
            'value' => 'restored',
            'expires' => future,
            'secure' => false,
            'http_only' => false
          }
        }
      }
    }

    @jar.load(data)

    assert_equal 'session=restored', @jar.cookie_header_for(uri)
  end

  def test_cookies_for_returns_array
    uri = URI.parse('https://example.com/')
    @jar.store_from_response(uri, { 'Set-Cookie' => ['a=1', 'b=2'] })

    cookies = @jar.cookies_for(uri)

    assert_instance_of Array, cookies
    assert_equal 2, cookies.size
  end

  def test_cookies_for_empty_uri_host
    uri = URI.parse('/relative/path')

    assert_empty @jar.cookies_for(uri)
  end

  def test_default_path_uses_request_path_directory
    uri = URI.parse('https://example.com/app/page.html')
    headers = { 'Set-Cookie' => 'session=abc' }
    @jar.store_from_response(uri, headers)

    # Default path should be /app (directory of /app/page.html)
    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/app/other'))
    assert_nil @jar.cookie_header_for(URI.parse('https://example.com/different'))
  end

  def test_handles_nil_headers
    uri = URI.parse('https://example.com/')
    @jar.store_from_response(uri, nil)

    assert_empty @jar
  end

  def test_handles_empty_set_cookie
    uri = URI.parse('https://example.com/')
    @jar.store_from_response(uri, { 'Set-Cookie' => '' })

    assert_empty @jar
  end

  def test_parses_cookie_with_domain_leading_dot
    uri = URI.parse('https://www.example.com/')
    headers = { 'Set-Cookie' => 'session=abc; Domain=.example.com' }
    @jar.store_from_response(uri, headers)

    # Leading dot should be stripped per RFC 6265
    assert_equal 'session=abc', @jar.cookie_header_for(URI.parse('https://example.com/'))
  end
end
