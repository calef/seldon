# frozen_string_literal: true

require_relative 'lib/seldon/version'

Gem::Specification.new do |spec|
  spec.name          = 'seldon'
  spec.version       = Seldon::VERSION
  spec.summary       = 'Shared HTTP, logging, and support utilities for Mayhem and Chio.'
  spec.description   = spec.summary
  spec.authors       = ['Mayhem Team']
  spec.email         = ['devs@kingcounty.solutions']
  spec.license       = 'MIT'
  spec.homepage      = 'https://github.com/calef/seldon'
  spec.required_ruby_version = '>= 3.4.8'

  spec.files = Dir.glob('lib/**/*.rb') + %w[README.md LICENSE]
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-typhoeus', '~> 1.0'
  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'rubocop-minitest', '~> 0.35'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
