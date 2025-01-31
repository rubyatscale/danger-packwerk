# typed: strict

module DangerPackwerk
  module Update
    class DefaultFormatter
      extend T::Sig
      include OffensesFormatter

      sig do
        params(
          custom_help_message: T.nilable(String)
        ).void
      end
      def initialize(custom_help_message: nil)
        @custom_help_message = custom_help_message
      end

      sig { override.params(offenses: T::Array[BasicReferenceOffense], repo_link: String, org_name: String, modularization_library: String).returns(String) }
      def format_offenses(offenses, repo_link, org_name, modularization_library: 'packwerk')
        violation = T.must(offenses.first)
        referencing_file_pack = ParsePackwerk.package_from_path(violation.file)
        # We remove leading double colons as they feel like an implementation detail of packwerk.
        constant_name = violation.class_name.delete_prefix('::')
        constant_source_package_name = violation.to_package_name

        constant_source_package = T.must(ParsePackwerk.find(constant_source_package_name))
        constant_source_package_owner = Private::OwnershipInformation.for_package(constant_source_package, org_name)

        package_referring_to_constant_owner = Private::OwnershipInformation.for_package(referencing_file_pack, org_name)

        if modularization_library == 'packwerk'
          disclaimer = 'We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.'
        elsif modularization_library == 'pks'
          disclaimer = 'We noticed you ran `bin/pks update`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.'
        end
        pluralized_violation = offenses.count > 1 ? 'these violations' : 'this violation'
        request_to_add_context = "- Could you add some context as a reply here about why we needed to add #{pluralized_violation}?\n"

        dependency_violation_message = "- cc #{package_referring_to_constant_owner.github_team} (#{package_referring_to_constant_owner.markdown_link_to_slack_room}) for the dependency violation.\n" if package_referring_to_constant_owner.owning_team

        privacy_violation_message = "- cc #{constant_source_package_owner.github_team} (#{constant_source_package_owner.markdown_link_to_slack_room}) for the privacy violation.\n" if constant_source_package_owner.owning_team

        if offenses.any?(&:dependency?) && offenses.any?(&:privacy?)
          <<~MESSAGE.chomp
            Hi again! It looks like `#{constant_name}` is private API of `#{constant_source_package_name}`, which is also not in `#{referencing_file_pack.name}`'s list of dependencies.
            #{disclaimer}

            #{request_to_add_context}#{dependency_violation_message}#{privacy_violation_message}
            #{@custom_help_message}
          MESSAGE
        elsif offenses.any?(&:dependency?)
          <<~MESSAGE.chomp
            Hi again! It looks like `#{constant_name}` belongs to `#{constant_source_package_name}`, which is not in `#{referencing_file_pack.name}`'s list of dependencies.
            #{disclaimer}

            #{request_to_add_context}#{dependency_violation_message}
            #{@custom_help_message}
          MESSAGE
        else # violations.any?(&:privacy?)
          <<~MESSAGE.chomp
            Hi again! It looks like `#{constant_name}` is private API of `#{constant_source_package_name}`.
            #{disclaimer}

            #{request_to_add_context}#{privacy_violation_message}
            #{@custom_help_message}
          MESSAGE
        end
      end
    end
  end
end
