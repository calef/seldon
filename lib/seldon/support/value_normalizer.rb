# frozen_string_literal: true

module Seldon
  module Support
    module ValueNormalizer
      module_function

      def normalize_value(value)
        return nil if value.nil?

        if value.is_a?(String)
          trimmed = value.strip
          return nil if trimmed.empty?

          trimmed
        elsif value.respond_to?(:empty?) && value.empty?
          nil
        else
          value
        end
      end
    end
  end
end
