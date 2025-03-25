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
          repo_url_builder: T.nilable(T.proc.params(constant_path: String).returns(String))
        ).returns(String)
      end
      def format_offenses(offenses, repo_link, org_name, repo_url_builder: nil); end
    end
  end
end
