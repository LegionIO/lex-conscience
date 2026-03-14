# frozen_string_literal: true

require_relative 'lib/legion/extensions/conscience/version'

Gem::Specification.new do |spec|
  spec.name          = 'legion-extensions-conscience'
  spec.version       = Legion::Extensions::Conscience::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@legionIO.com']
  spec.summary       = 'Moral reasoning engine for LegionIO cognitive agents'
  spec.description   = 'Applies Moral Foundations Theory to evaluate proposed actions, track moral consistency, and surface ethical dilemmas before execution'
  spec.homepage      = 'https://github.com/LegionIO/lex-conscience'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
end
