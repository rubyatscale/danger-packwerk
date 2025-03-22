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

    sig { returns(ConstantResolver) }
    def self.constant_resolver
      @constant_resolver ||= T.let(
        begin
          load_paths = Packwerk::RailsLoadPaths.for(Dir.pwd, environment: 'test')
          ConstantResolver.new(
            root_path: Dir.pwd,
            load_paths: T.unsafe(load_paths).keys
          )
        end,
        T.nilable(ConstantResolver)
      )
    end
  end

  private_constant :Private
end
