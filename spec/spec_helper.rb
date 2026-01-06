# frozen_string_literal: true

require 'bundler/setup'
require 'cork'
require 'json'
require 'packs'
require 'packs/rspec/support'

# Packwerk types are still available as test doubles via the packs transitive dependency.
# The production code no longer directly depends on packwerk, but tests can use it for mocking.
require 'packwerk'

module DangerHelpers
  # These functions are a subset of https://github.com/danger/danger/blob/master/spec/spec_helper.rb
  # If you are expanding these files, see if it's already been done ^.

  def testing_ui
    @output = StringIO.new

    cork = Cork::Board.new(out: @output)
    def cork.string
      out.string.gsub(/\e\[([;\d]+)?m/, '')
    end
    cork
  end

  # Example environment (ENV) that would come from
  # running a PR on Buildkite
  def testing_env
    {
      'BUILDKITE_REPO' => 'git@github.com:rubyatscale/danger-packwerk.git',
      'BUILDKITE' => true,
      'DANGER_GITHUB_API_TOKEN' => 'some_token',
      'DANGER_GITHUB_BEARER_TOKEN' => 'some_other_token'
    }
  end

  # A stubbed out Dangerfile for use in tests
  def testing_dangerfile
    env = Danger::EnvironmentManager.new(testing_env)
    Danger::Dangerfile.new(env, testing_ui)
  end
end

require 'pry'
require_relative 'support/danger_plugin'
require_relative 'support/custom_matchers'
require 'danger-packwerk'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  config.include_context 'danger plugin'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include DangerHelpers

  config.before do |_example|
    ParsePackwerk.bust_cache!
    DangerPackwerk.send(:const_get, :Private).instance_variable_set(:@constant_resolver, nil)
  end
end

def sorbet_double(stubbed_class, attr_map = {})
  instance_double(stubbed_class, attr_map).tap do |dbl|
    allow(dbl).to receive(:is_a?) { |tested_class| stubbed_class.ancestors.include?(tested_class) }
  end
end

def write_package_yml(
  pack_name
)
  write_pack(pack_name, { 'enforce_dependencies' => true, 'enforce_privacy' => true })
end
