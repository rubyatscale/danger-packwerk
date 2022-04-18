# typed: strict

module DangerPackwerk
  #
  # This class represents the change in violations between a PR and its base.
  #
  class ViolationDiff < T::Struct
    extend T::Sig

    const :added_violations, T::Array[BasicReferenceOffense]
    const :removed_violations, T::Array[BasicReferenceOffense]
    const :all_violations_before, T::Array[BasicReferenceOffense]
  end
end
