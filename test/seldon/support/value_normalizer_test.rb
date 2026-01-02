# frozen_string_literal: true

require_relative '../../test_helper'
require 'minitest/autorun'

class ValueNormalizerTest < Minitest::Test
  def test_normalize_value_with_nil
    assert_nil Seldon::Support::ValueNormalizer.normalize_value(nil)
  end

  def test_normalize_value_with_string
    assert_equal 'foo', Seldon::Support::ValueNormalizer.normalize_value('  foo  ')
    assert_equal 'bar', Seldon::Support::ValueNormalizer.normalize_value('bar')
  end

  def test_normalize_value_with_empty_string
    assert_nil Seldon::Support::ValueNormalizer.normalize_value('')
    assert_nil Seldon::Support::ValueNormalizer.normalize_value('   ')
  end

  def test_normalize_value_with_empty_array
    assert_nil Seldon::Support::ValueNormalizer.normalize_value([])
  end

  def test_normalize_value_with_non_empty_array
    assert_equal [1, 2, 3], Seldon::Support::ValueNormalizer.normalize_value([1, 2, 3])
  end

  def test_normalize_value_with_empty_hash
    assert_nil Seldon::Support::ValueNormalizer.normalize_value({})
  end

  def test_normalize_value_with_non_empty_hash
    assert_equal({ foo: 'bar' }, Seldon::Support::ValueNormalizer.normalize_value({ foo: 'bar' }))
  end

  def test_normalize_value_with_number
    assert_equal 42, Seldon::Support::ValueNormalizer.normalize_value(42)
    assert_equal 3.14, Seldon::Support::ValueNormalizer.normalize_value(3.14)
  end

  def test_normalize_value_with_boolean
    assert_equal true, Seldon::Support::ValueNormalizer.normalize_value(true)
    assert_equal false, Seldon::Support::ValueNormalizer.normalize_value(false)
  end
end
