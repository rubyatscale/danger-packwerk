# typed: strict

require 'code_ownership'

module DangerPackwerk
  module Check
    class DefaultFormatter
      include OffensesFormatter
      extend T::Sig

      sig do
        params(
          custom_help_message: T.nilable(String)
        ).void
      end
      def initialize(custom_help_message: nil)
        @custom_help_message = custom_help_message
      end

      sig do
        override.params(
          offenses: T::Array[Packwerk::ReferenceOffense],
          plugin: Danger::Plugin,
          org_name: String
        ).returns(String)
      end
      def format_offenses(offenses, plugin, org_name)
        reference_offense = T.must(offenses.first)
        violation_types = offenses.map(&:violation_type)
        referencing_file = reference_offense.reference.relative_path
        referencing_file_pack = ParsePackwerk.package_from_path(referencing_file).name
        # We remove leading double colons as they feel like an implementation detail of packwerk.
        constant_name = reference_offense.reference.constant.name.delete_prefix('::')

        constant_source_package_name = reference_offense.reference.constant.package.name

        constant_location = reference_offense.reference.constant.location
        constant_source_package = T.must(ParsePackwerk.all.find { |p| p.name == constant_source_package_name })
        constant_source_package_ownership_info = Private::OwnershipInformation.for_package(constant_source_package, org_name)

        disclaimer = 'Before you run `bin/packwerk update-todo`, check out these quick suggestions:'
        referencing_code_in_right_pack = "- Does the code you are writing live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{referencing_file}`"
        referenced_code_in_right_pack = "- Does #{constant_name} live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{constant_location}`"
        dependency_violation_message = "- Do we actually want to depend on #{constant_source_package_name}?\n  - If so, try `bin/packs add_dependency #{referencing_file_pack} #{constant_source_package_name}`\n  - If not, what can we change about the design so we do not have to depend on #{constant_source_package_name}?"
        team_to_work_with = constant_source_package_ownership_info.owning_team ? constant_source_package_ownership_info.markdown_link_to_github_members_no_tag : 'the pack owner'

        privacy_violation_message = "- Does API in #{constant_source_package.name}/public support this use case?\n  - If not, can we work with #{team_to_work_with} to create and use a public API?\n  - If `#{constant_name}` should already be public, try `bin/packs make_public #{constant_location}`."
        constant_link = "`#{constant_name}` (#{plugin.github.html_link(constant_location)})"

        if violation_types.include?(::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE) && violation_types.include?(::DangerPackwerk::PRIVACY_VIOLATION_TYPE)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock: + Dependency :knot:
            - Constant: #{constant_link}
            - Owning pack: #{constant_source_package_name}
              #{constant_source_package_ownership_info.ownership_copy}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{dependency_violation_message}
            #{privacy_violation_message}

            </details>

            _#{@custom_help_message}_
          MESSAGE
        elsif violation_types.include?(::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Dependency :knot:
            - Constant: #{constant_link}
            - Owning pack: #{constant_source_package_name}
              #{constant_source_package_ownership_info.ownership_copy}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{dependency_violation_message}

            </details>

            _#{@custom_help_message}_
          MESSAGE
        else # violation_types.include?(::DangerPackwerk::PRIVACY_VIOLATION_TYPE)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock:
            - Constant: #{constant_link}
            - Owning pack: #{constant_source_package_name}
              #{constant_source_package_ownership_info.ownership_copy}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{privacy_violation_message}

            </details>

            _#{@custom_help_message}_
          MESSAGE
        end
      end
    end
  end
end
