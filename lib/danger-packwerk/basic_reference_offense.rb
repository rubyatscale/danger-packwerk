# typed: strict

module DangerPackwerk
  #
  # We call this BasicReferenceOffense as it is intended to have a subset of the interface of Packwerk::ReferenceOffense, located here:
  # https://github.com/Shopify/packwerk/blob/a22862b59f7760abf22bda6804d41a52d05301d8/lib/packwerk/reference_offense.rb#L1
  # However, we cannot actually construct a Packwerk::ReferenceOffense from `package_todo.yml` alone, since they are normally
  # constructed in packwerk when packwerk parses the AST and actually outputs `package_todo.yml`, a process in which some information,
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
    const :from_package_name, String
    const :type, String
    const :file_location, Location

    sig { params(package_todo_yml: String).returns(T::Array[BasicReferenceOffense]) }
    def self.from(package_todo_yml)
      package_todo_yml_pathname = Pathname.new(package_todo_yml)

      from_package = ParsePackwerk.package_from_path(package_todo_yml_pathname)
      from_package_name = from_package.name
      violations = ParsePackwerk::PackageTodo.from(package_todo_yml_pathname).violations

      # See the larger comment below for more information on why we need this information.
      # This is a small optimization that lets us find the location of referenced files within
      # a `package_todo.yml` file. Getting this now allows us to avoid reading through the file
      # once for every referenced file in the inner loop below.
      file_reference_to_line_number_index = T.let({}, T::Hash[String, T::Array[Integer]])
      all_referenced_files = violations.flat_map(&:files).uniq
      package_todo_yml_pathname.readlines.each_with_index do |line, index|
        # We can use `find` here to exit early since each line will include one path that is unique to that file.
        # Paths should not be substrings of each other, since they are all paths relative to the root.
        file_on_line = all_referenced_files.find { |file| line.include?(file) }
        # Not all lines contain a reference to a file
        if file_on_line
          file_reference_to_line_number_index[file_on_line] ||= []
          file_reference_to_line_number_index.fetch(file_on_line) << index
        end
      end

      violations.flat_map do |violation|
        #
        # We identify two locations associated with this violation.
        # First, we find the reference to the constant within the `package_todo.yml` file.
        # We know that each constant reference can occur only once per `package_todo.yml` file
        # The reason for this is that we know that only one file in the codebase can define a constant, and packwerk's constant_resolver will actually
        # raise if this assumption is not true: https://github.com/Shopify/constant_resolver/blob/e78af0c8d5782b06292c068cfe4176e016c51b34/lib/constant_resolver.rb#L74
        #
        # Second, we find the reference to the specific file that references the constant within the `package_todo.yml` file.
        # This can occur multiple times per `package_todo.yml` file, but we know that the very first reference to the file after the class name key will be the one we care
        # about, so we take the first instance that occurs after the class is listed.
        #
        # Note though that since one constant reference in a `package_todo.yml` can be both a privacy and a dependency violation AND it can occur in many files,
        # we need to group them. That is -- if `MyPrivateConstant` is both a dependency and a privacy violation AND it occurs in 10 files, that would represent 20 violations.
        # Therefore we will group all of those 20 into one message to the user rather than providing 20 messages.
        #
        _line, class_name_line_number = package_todo_yml_pathname.readlines.each_with_index.find do |line, _index|
          # If you have a class `::MyClass`, then you can get a false match if another constant in the file
          # is named `MyOtherClass::MyClassThing`. Therefore we include quotes in our match to ensure that we match
          # the constant and only the constant.
          # Right now `packwerk` `package_todo.yml` files typically use double quotes, but sometimes folks linters change this to single quotes.
          # To be defensive, we match against either.
          class_name_with_quote_boundaries = /["|']#{violation.class_name}["|']:/
          line.match?(class_name_with_quote_boundaries)
        end

        if class_name_line_number.nil?
          debug_info = { class_name: violation.class_name, to_package_name: violation.to_package_name, type: violation.type }
          raise "Unable to find reference to violation #{debug_info} in #{package_todo_yml}"
        end

        violation.files.map do |file|
          file_line_numbers = file_reference_to_line_number_index.fetch(file, [])
          file_line_number = file_line_numbers.select { |index| index > class_name_line_number }.min
          raise "Unable to find reference to violation #{{ file: file, to_package_name: violation.to_package_name, type: violation.type }} in #{package_todo_yml}" if file_line_number.nil?

          # We add one to the line number since `each_with_index` is zero-based indexed but Github line numbers are one-based indexed
          file_location = Location.new(file: package_todo_yml, line_number: file_line_number + 1)

          BasicReferenceOffense.new(
            class_name: violation.class_name,
            file: file,
            to_package_name: violation.to_package_name,
            type: violation.type,
            file_location: file_location,
            from_package_name: from_package_name
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
