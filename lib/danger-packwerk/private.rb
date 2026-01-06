# typed: strict

require 'danger-packwerk/private/ownership_information'
require 'danger-packwerk/private/todo_yml_changes'
require 'constant_resolver'

module DangerPackwerk
  #
  # Anything within the Private module is subject to change.
  #
  module Private
    extend T::Sig

    # Common Rails autoload paths
    RAILS_DEFAULT_AUTOLOAD_PATHS = T.let(%w[
      app/models
      app/controllers
      app/helpers
      app/mailers
      app/jobs
      app/services
      app/lib
      lib
    ].freeze, T::Array[String])

    sig { returns(T::Array[String]) }
    def self.infer_load_paths
      root = Dir.pwd
      paths = RAILS_DEFAULT_AUTOLOAD_PATHS.map { |p| File.join(root, p) }
      paths += Dir.glob(File.join(root, 'packs', '*', 'app', '**'))
      paths += Dir.glob(File.join(root, 'packs', '*'))
      paths.select { |p| File.directory?(p) }
    end

    sig { void }
    def self.reset_constant_resolver!
      @constant_resolver = nil
    end

    sig { returns(T.nilable(ConstantResolver)) }
    def self.constant_resolver
      @constant_resolver ||= T.let(
        begin
          load_paths = infer_load_paths
          return nil if load_paths.empty?

          ConstantResolver.new(
            root_path: Dir.pwd,
            load_paths: load_paths
          )
        end,
        T.nilable(ConstantResolver)
      )
    end
  end

  private_constant :Private
end
