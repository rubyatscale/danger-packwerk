# typed: strict

require 'json'

module DangerPackwerk
  #
  # PksOffense represents a violation from pks JSON output.
  # It is designed to have a compatible interface with BasicReferenceOffense
  # so it can be used with the Update::OffensesFormatter.
  #
  class PksOffense < T::Struct
    extend T::Sig

    const :violation_type, String
    const :file, String
    const :line, Integer
    const :column, Integer
    const :constant_name, String
    const :referencing_pack_name, String
    const :defining_pack_name, String
    const :strict, T::Boolean
    const :message, String

    # Alias methods for compatibility with BasicReferenceOffense interface
    sig { returns(String) }
    def class_name
      constant_name
    end

    sig { returns(String) }
    def type
      violation_type
    end

    sig { returns(String) }
    def to_package_name
      defining_pack_name
    end

    sig { returns(String) }
    def from_package_name
      referencing_pack_name
    end

    sig { returns(T::Boolean) }
    def privacy?
      violation_type == PRIVACY_VIOLATION_TYPE
    end

    sig { returns(T::Boolean) }
    def dependency?
      violation_type == DEPENDENCY_VIOLATION_TYPE
    end

    sig { params(other: PksOffense).returns(T::Boolean) }
    def ==(other)
      other.constant_name == constant_name &&
        other.file == file &&
        other.defining_pack_name == defining_pack_name &&
        other.violation_type == violation_type
    end

    sig { params(other: PksOffense).returns(T::Boolean) }
    def eql?(other)
      self == other
    end

    sig { returns(Integer) }
    def hash
      [constant_name, file, defining_pack_name, violation_type].hash
    end

    class << self
      extend T::Sig

      sig { params(json_string: String).returns(T::Array[PksOffense]) }
      def from_json(json_string)
        data = JSON.parse(json_string)
        offenses = data['offenses'] || []
        offenses.map { |offense| from_hash(offense) }
      end

      sig { params(hash: T::Hash[String, T.untyped]).returns(PksOffense) }
      def from_hash(hash)
        PksOffense.new(
          violation_type: hash.fetch('violation_type'),
          file: hash.fetch('file'),
          line: hash.fetch('line'),
          column: hash.fetch('column'),
          constant_name: hash.fetch('constant_name'),
          referencing_pack_name: hash.fetch('referencing_pack_name'),
          defining_pack_name: hash.fetch('defining_pack_name'),
          strict: hash.fetch('strict', false),
          message: hash.fetch('message', '')
        )
      end
    end
  end
end
