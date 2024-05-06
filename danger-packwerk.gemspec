# frozen_string_literal: true

require_relative 'lib/danger-packwerk/version'

Gem::Specification.new do |spec|
  spec.name          = 'danger-packwerk'
  spec.version       = DangerPackwerk::VERSION
  spec.authors       = ['Gusto Engineers']
  spec.email         = ['dev@gusto.com']
  spec.description   = 'Danger plugin for packwerk.'
  spec.summary       = 'Danger plugin for packwerk.'
  spec.homepage      = 'https://github.com/rubyatscale/danger-packwerk'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/rubyatscale/danger-packwerk'
    spec.metadata['changelog_uri'] = 'https://github.com/rubyatscale/danger-packwerk/releases'
  end

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  spec.files = Dir['README.md', 'lib/**/*']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'code_ownership'
  spec.add_dependency 'danger-plugin-api', '~> 1.0'
  spec.add_dependency 'packs'
  spec.add_dependency 'packwerk'
  spec.add_dependency 'parse_packwerk'
  spec.add_dependency 'sorbet-runtime'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-sorbet'
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
end
