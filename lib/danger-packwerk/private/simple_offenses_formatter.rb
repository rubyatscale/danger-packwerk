# typed: strict

module DangerPackwerk
  module Private
    class SimpleAddedOffensesFormatter
      extend T::Sig

      sig { params(violations: T::Array[BasicReferenceOffense]).returns(String) }
      def self.format(violations)
        violation = T.must(violations.first)
        # We remove leading double colons as they feel like an implementation detail of packwerk.
        constant_name = violation.class_name.gsub(/\A::/, '')
        link_to_docs = '[the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf)'
        disclaimer = "We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through #{link_to_docs} for other ways to resolve. "
        pluralized_violation = violations.count > 1 ? 'these violations' : 'this violation'
        request_to_add_context = "Could you add some context as a reply here about why we needed to add #{pluralized_violation}?"

        if violations.any?(&:dependency?) && violations.any?(&:privacy?)
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` considers this private API, and it's also not in the referencing pack's list of dependencies.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        elsif violations.any?(&:dependency?)
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` is not in the referencing pack's list of dependencies.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        else # violations.any?(&:privacy?)
          <<~MESSAGE
            Hi! It looks like the pack defining `#{constant_name}` considers this private API.
            #{disclaimer}#{request_to_add_context}
          MESSAGE
        end
      end
    end
  end
end
