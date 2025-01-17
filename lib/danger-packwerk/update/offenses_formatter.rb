# typed: strict

require 'code_ownership'

module DangerPackwerk
  module Update
    module OffensesFormatter
      extend T::Sig
      extend T::Helpers

      interface!

      sig do
        abstract.params(
          offenses: T::Array[BasicReferenceOffense],
          repo_link: String,
          org_name: String,
          modularization_library: String
        ).returns(String)
      end
      def format_offenses(offenses, repo_link, org_name, modularization_library: 'packwerk'); end
    end
  end
end
