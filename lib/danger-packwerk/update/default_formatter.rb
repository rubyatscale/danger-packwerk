# typed: strict

module DangerPackwerk
  module Update
    class DefaultFormatter
      extend T::Sig
      include OffensesFormatter

      sig { override.params(offenses: T::Array[BasicReferenceOffense], repo_link: String, org_name: String).returns(String) }
      def format_offenses(offenses, repo_link, org_name)
        offense = T.must(offenses.first)
        constant_name = offense.class_name.delete_prefix('::')
        link_to_docs = '[the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf)'
        disclaimer = "We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through #{link_to_docs} for other ways to resolve. "
        pluralized_violation = offenses.count > 1 ? 'these violations' : 'this violation'
        request_to_add_context = "Could you add some context as a reply here about why we needed to add #{pluralized_violation}?"
        violation_types = offenses.map(&:type)

        if violation_types.include?('dependency') && violation_types.include?('privacy')
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` considers this private API, and it's also not in the referencing pack's list of dependencies.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        elsif violation_types.include?('dependency')
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` is not in the referencing pack's list of dependencies.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        else # violation_types.include?('privacy')
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` considers this private API.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        end
      end
    end
  end
end
