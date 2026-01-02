# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'seldon'

begin
  require 'minitest/mock'
rescue LoadError
  module SeldonStubSupport
    def stub(name, replacement = nil, &block)
      raise ArgumentError, 'stub requires a block' unless block

      stub_proc = replacement.respond_to?(:call) ? replacement : proc { replacement }
      eigenclass = singleton_class
      had_original = eigenclass.method_defined?(name) || eigenclass.private_method_defined?(name)
      original = eigenclass.instance_method(name) if had_original

      eigenclass.send(:define_method, name) do |*args, **kwargs, &method_block|
        if kwargs.empty?
          stub_proc.call(*args, &method_block)
        else
          begin
            stub_proc.call(*args, **kwargs, &method_block)
          rescue ArgumentError
            stub_proc.call(*args, &method_block)
          end
        end
      end

      block.call
    ensure
      begin
        eigenclass.send(:remove_method, name)
      rescue NameError
        # ignore if method already removed
      end
      eigenclass.send(:define_method, name, original) if had_original
    end
  end

  Object.include(SeldonStubSupport)
  Module.include(SeldonStubSupport)
end
