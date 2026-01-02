# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require 'stringio'

class LoggingTest < Minitest::Test
  class FakeLoggable
    include Seldon::Loggable
  end

  def setup
    @original_log_level = ENV['LOG_LEVEL']
    Seldon::Logging.reset_logger
  end

  def teardown
    ENV['LOG_LEVEL'] = @original_log_level
    Seldon::Logging.reset_logger
  end

  def test_logger_writes_json_to_stdout_for_non_warn_levels
    logger = build_logger_with_level(:debug)
    payload = capture_logs(logger, level: :info)

    assert_equal 'INFO', payload['severity_text']
    assert_equal 'hello', payload['body']
    assert_equal 'test-app', payload['attributes']['program_name']
    assert_equal 'cid', payload['attributes']['correlation_id']
    assert payload['attributes']['thread'].is_a?(Integer)
    assert_equal 9, payload['severity_number']
  end

  def test_logger_writes_to_stderr_for_warn_and_above
    logger = build_logger_with_level(:warn)
    stderr_payload = capture_logs(logger, level: :warn, stream: :stderr)

    assert_equal 'WARN', stderr_payload['severity_text']
    assert_equal 'warning', stderr_payload['body']
  end

  def test_build_logger_respects_environment_override
    ENV['LOG_LEVEL'] = 'ERROR'
    logger = Seldon::Logging.build_logger(env_var: 'LOG_LEVEL', default_level: 'INFO', program_name: 'env-app')

    stdout_payload = capture_logs(logger, level: :info)
    assert_nil stdout_payload

    stderr_payload = capture_logs(logger, level: :error, stream: :stderr)
    assert_equal 'env-app', stderr_payload['attributes']['program_name']
    assert_equal 'ERROR', stderr_payload['severity_text']
  end

  def test_new_correlation_id_generates_unique_value
    logger = Seldon::Logging::Logger.new(level_value: 0, program_name: 'test', correlation_id: 'initial')
    assert_equal 'initial', logger.correlation_id

    logger.new_correlation_id
    refute_equal 'initial', logger.correlation_id
  end

  def test_logger_cache_and_reset
    proxy = Seldon::Logging::Logger.new(level_value: 0, program_name: 'cached', correlation_id: 'cache')
    Seldon::Logging.logger = proxy

    assert_same proxy, Seldon::Logging.logger
    Seldon::Logging.reset_logger

    refute_same proxy, Seldon::Logging.logger
  end

  def test_loggable_uses_shared_logger_and_allows_override
    shared_logger = Seldon::Logging.logger
    loggable = FakeLoggable.new

    assert_same shared_logger, loggable.logger

    custom_logger = Seldon::Logging::Logger.new(level_value: 0, program_name: 'custom')
    loggable.logger = custom_logger
    assert_same custom_logger, loggable.logger
  end

  private

  def build_logger_with_level(level_name)
    level_value = Seldon::Logging::LEVELS[level_name.to_s.upcase]
    Seldon::Logging::Logger.new(level_value: level_value, program_name: 'test-app', correlation_id: 'cid')
  end

  def capture_logs(logger, level:, stream: :stdout)
    buffer = StringIO.new

    original = stream == :stderr ? $stderr : $stdout
    begin
      if stream == :stderr
        $stderr = buffer
      else
        $stdout = buffer
      end

      time = Time.utc(2024, 1, 1, 0, 0, 0)
      Time.stub(:now, time) do
        logger.public_send(level, stream == :stderr ? 'warning' : 'hello')
      end
    ensure
      if stream == :stderr
        $stderr = original
      else
        $stdout = original
      end
    end

    buffer.seek(0)
    return if buffer.string.empty?

    line = buffer.string.lines.map(&:strip).find { |entry| entry.start_with?('{') }
    return unless line

    JSON.parse(line)
  end
end
