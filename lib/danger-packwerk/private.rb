# typed: strict

require 'danger-packwerk/private/ownership_information'
require 'danger-packwerk/private/todo_yml_changes'
require 'constant_resolver'
require 'parse_packwerk'

module DangerPackwerk
  #
  # Anything within the Private module is subject to change.
  #
  module Private
    extend T::Sig

    # Standard Rails autoload subdirectories within packages
    AUTOLOAD_SUBDIRS = T.let(%w[
      app/models
      app/controllers
      app/services
      app/jobs
      app/mailers
      app/helpers
      app/views
      app/channels
      app/components
      lib
    ].freeze, T::Array[String])

    sig { returns(ConstantResolver) }
    def self.constant_resolver
      @constant_resolver ||= T.let(
        begin
          load_paths = discover_load_paths
          ConstantResolver.new(
            root_path: Dir.pwd,
            load_paths: load_paths
          )
        end,
        T.nilable(ConstantResolver)
      )
    end

    sig { returns(T::Array[String]) }
    def self.discover_load_paths
      paths = []

      # Add top-level autoload paths
      AUTOLOAD_SUBDIRS.each do |subdir|
        path = File.join(Dir.pwd, subdir)
        paths << subdir if File.directory?(path)
      end

      # Add autoload paths from each package
      ParsePackwerk.all.each do |package|
        next if package.name == '.'

        has_standard_subdirs = false
        AUTOLOAD_SUBDIRS.each do |subdir|
          path = File.join(Dir.pwd, package.name, subdir)
          relative_path = File.join(package.name, subdir)
          if File.directory?(path)
            paths << relative_path
            has_standard_subdirs = true
          end
        end

        # Fallback: if no standard Rails subdirs exist, use the pack root
        # This supports non-standard pack structures and test environments
        unless has_standard_subdirs
          pack_path = File.join(Dir.pwd, package.name)
          paths << package.name if File.directory?(pack_path)
        end
      end

      paths
    end
  end

  private_constant :Private
end
