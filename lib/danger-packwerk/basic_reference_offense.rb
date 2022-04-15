# typed: strict

module DangerPackwerk
  #
  # We call this BasicReferenceOffense as it is intended to have a subset of the interface of Packwerk::ReferenceOffense, located here:
  # https://github.com/Shopify/packwerk/blob/a22862b59f7760abf22bda6804d41a52d05301d8/lib/packwerk/reference_offense.rb#L1
  # However, we cannot actually construct a Packwerk::ReferenceOffense from `deprecated_referencs.yml` alone, since they are normally
  # constructed in packwerk when packwerk parses the AST and actually outputs `deprecated_references.yml`, a process in which some information,
  # such as the location where the constant is defined, is lost.
  #
  class BasicReferenceOffense < T::Struct
    class Location < T::Struct
      extend T::Sig

      const :file, String
      const :line_number, Integer

      #
      # These two methods exist so we can use `group_by` to group a `T::Array[BasicReferenceOffense]` by location.
      #
      sig { params(other: Location).returns(T::Boolean) }
      def eql?(other)
        file == other.file && line_number == other.line_number
      end

      sig { returns(Integer) }
      def hash
        [file, line_number].hash
      end
      #
      # End method group
      #
    end

    extend T::Sig

    const :class_name, String
    const :file, String
    const :to_package_name, String
    const :type, String
    const :location, Location

    sig { params(deprecated_references_yml: String).returns(T::Array[BasicReferenceOffense]) }
    def self.from(deprecated_references_yml)
      deprecated_references_yml_pathname = Pathname.new(deprecated_references_yml)
      violations = Private::DeprecatedReferences.from(deprecated_references_yml_pathname).violations

      violations.flat_map do |violation|
        # We choose the location of the violation as the reference to the constant within the `deprecated_references.yml` file.
        # We simply find the reference to that constant, because we know that each constant reference can occur only once per `deprecated_references.yml` file
        # The reason for this is that we know that only one file in the codebase can define a constant, and packwerk's constant_resolver will actually
        # raise if this assumption is not true: https://github.com/Shopify/constant_resolver/blob/e78af0c8d5782b06292c068cfe4176e016c51b34/lib/constant_resolver.rb#L74
        #
        # Note though that since one constant reference in a `deprecated_referencs.yml` can be both a privacy and a dependency violation AND it can occur in many files,
        # we need to group them. That is -- if `MyPrivateConstant` is both a dependency and a privacy violation AND it occurs in 10 files, that would represent 20 violations.
        # Therefore we will group all of those 20 into one message to the user rather than providing 20 messages.
        _line, line_number = deprecated_references_yml_pathname.readlines.each_with_index.find { |line, _index| line.include?(violation.class_name) }
        if line_number.nil?
          debug_info = { class_name: violation.class_name, to_package_name: violation.to_package_name, type: violation.type }
          raise "Unable to find reference to violation #{debug_info} in #{deprecated_references_yml}"
        end

        # We add one to the line number since `each_with_index` is zero-based indexed but Github line numbers are one-based indexed
        location = Location.new(file: deprecated_references_yml, line_number: line_number + 1)

        violation.files.map do |file|
          BasicReferenceOffense.new(
            class_name: violation.class_name,
            file: file,
            to_package_name: violation.to_package_name,
            type: violation.type,
            location: location
          )
        end
      end
    end

    sig { returns(T::Boolean) }
    def privacy?
      type == 'privacy'
    end

    sig { returns(T::Boolean) }
    def dependency?
      type == 'dependency'
    end

    sig { params(other: BasicReferenceOffense).returns(T::Boolean) }
    def ==(other)
      other.class_name == class_name &&
        other.file == file &&
        other.to_package_name == to_package_name &&
        other.type == type
    end

    sig { params(other: BasicReferenceOffense).returns(T::Boolean) }
    def eql?(other)
      self == other
    end

    sig { returns(Integer) }
    def hash
      [class_name, file, to_package_name, type].hash
    end
  end
end
