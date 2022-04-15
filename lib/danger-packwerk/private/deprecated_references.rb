# typed: strict

module DangerPackwerk
  module Private
    #
    # The `Violation` and `DeprecatedReferences` classes come from Gusto's private `ParsePackwerk` gem.
    # Until we decide to open source that gem, we inline these as a private implementation detail of `DangerPackwerk` for now.
    #
    class Violation < T::Struct
      extend T::Sig

      const :type, String
      const :to_package_name, String
      const :class_name, String
      const :files, T::Array[String]

      sig { returns(T::Boolean) }
      def dependency?
        type == 'dependency'
      end

      sig { returns(T::Boolean) }
      def privacy?
        type == 'privacy'
      end
    end

    class DeprecatedReferences < T::Struct
      extend T::Sig

      const :pathname, Pathname
      const :violations, T::Array[Violation]

      sig { params(pathname: Pathname).returns(DeprecatedReferences) }
      def self.from(pathname)
        if pathname.exist?
          deprecated_references_loaded_yml = YAML.load_file(pathname)

          all_violations = []
          deprecated_references_loaded_yml&.each_key do |to_package_name|
            deprecated_references_per_package = deprecated_references_loaded_yml[to_package_name]
            deprecated_references_per_package.each_key do |class_name|
              symbol_usage = deprecated_references_per_package[class_name]
              files = symbol_usage['files']
              violations = symbol_usage['violations']
              all_violations << Violation.new(type: 'dependency', to_package_name: to_package_name, class_name: class_name, files: files) if violations.include? 'dependency'

              all_violations << Violation.new(type: 'privacy', to_package_name: to_package_name, class_name: class_name, files: files) if violations.include? 'privacy'
            end
          end

          new(
            pathname: pathname.cleanpath,
            violations: all_violations
          )
        else
          new(
            pathname: pathname.cleanpath,
            violations: []
          )
        end
      end
    end
  end
end
