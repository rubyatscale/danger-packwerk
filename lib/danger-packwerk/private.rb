# typed: strict

require 'danger-packwerk/private/package_todo'
require 'danger-packwerk/private/ownership_information'
require 'constant_resolver'

module DangerPackwerk
  #
  # Anything within the Private module is subject to change.
  #
  module Private
    extend T::Sig

    sig { returns(ConstantResolver) }
    def self.constant_resolver
      @constant_resolver = T.let(@constant_resolver, T.nilable(ConstantResolver))
      @constant_resolver ||= begin
        load_paths = Packwerk::ApplicationLoadPaths.extract_relevant_paths(Dir.pwd, 'test')
        ConstantResolver.new(
          root_path: Dir.pwd,
          load_paths: T.unsafe(load_paths).keys
        )
      end
    end
  end

  private_constant :Private
end
