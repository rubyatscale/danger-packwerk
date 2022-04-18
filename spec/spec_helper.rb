# frozen_string_literal: true

require 'bundler/setup'
require 'cork'
require 'json'

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
      'BUILDKITE_REPO' => 'git@github.com:bigrails/danger-packwerk.git',
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
require_relative 'support/contain_inline_markdown'
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

  config.around do |example|
    prefix = [File.basename($0), Process.pid].join('-') # rubocop:disable Style/SpecialGlobalVars
    tmpdir = Dir.mktmpdir(prefix)
    Dir.chdir(tmpdir) do
      example.run
    end
  ensure
    FileUtils.rm_rf(tmpdir)
  end
end

def write_file(path, content = '')
  pathname = Pathname.new(path)
  FileUtils.mkdir_p(pathname.dirname)
  pathname.write(content)
  path
end

def sorbet_double(stubbed_class, attr_map = {})
  instance_double(stubbed_class, attr_map).tap do |dbl|
    allow(dbl).to receive(:is_a?) { |tested_class| stubbed_class.ancestors.include?(tested_class) }
  end
end
