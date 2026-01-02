# frozen_string_literal: true

require_relative '../../test_helper'
require 'minitest/autorun'

class HttpClientSmokeTest < Minitest::Test
  def test_http_client_instantiation
    client = Seldon::Support::HttpClient.new

    assert_respond_to client, :fetch
  end
end
