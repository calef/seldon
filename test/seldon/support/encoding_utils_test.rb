# frozen_string_literal: true

require_relative '../../test_helper'

module Seldon
  module Support
    class EncodingUtilsTest < Minitest::Test
      def test_ensure_utf8_returns_empty_string_for_nil
        assert_equal '', EncodingUtils.ensure_utf8(nil)
      end

      def test_ensure_utf8_preserves_ascii_text
        input = 'plain text'
        assert_equal input, EncodingUtils.ensure_utf8(input)
      end

      def test_ensure_utf8_removes_invalid_bytes
        binary = "\xFF".dup.force_encoding('ASCII-8BIT')
        assert_equal '', EncodingUtils.ensure_utf8(binary)
      end

      def test_ensure_utf8_handles_objects_that_raise_when_encoded
        broken = Class.new do
          def to_s
            raise ArgumentError, 'no string'
          end
        end.new

        assert_raises(ArgumentError) { EncodingUtils.ensure_utf8(broken) }
      end
    end
  end
end
