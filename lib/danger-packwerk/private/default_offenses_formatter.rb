# typed: strict

module DangerPackwerk
  module Private
    class DefaultAddedOffensesFormatter
      extend T::Sig

      sig { params(violations: T::Array[BasicReferenceOffense]).returns(String) }
      def self.format(violations)
        reference_offense = T.must(offenses.first)
        violation_types = offenses.map(&:violation_type)
        referencing_file = reference_offense.reference.relative_path
        referencing_file_pack = Private.package_names_for_files([referencing_file]).first
        # We remove leading double colons as they feel like an implementation detail of packwerk.
        constant_name = reference_offense.reference.constant.name.delete_prefix('::')
        constant_source_package_name = reference_offense.reference.constant.package.name
        constant_location = reference_offense.reference.constant.location
        constant_source_package = T.must(ParsePackwerk.all.find { |p| p.name == constant_source_package_name })
        constant_source_package_owner = CodeOwnership.for_package(constant_source_package)

        ruby_modularity_slack_channel = DangerPlugins.markdown_link_to_slack_room('#ruby-modularity')

        if constant_source_package_owner
          github_team = GustoTeams::Plugins::Github.for(constant_source_package_owner).github.team
          slack_channel = GustoTeams::Plugins::Slack.for(constant_source_package_owner).slack.room_for_humans

          team_to_work_with = DangerPlugins.markdown_link_to_github_members_no_tag(github_team)
          team_to_work_with_slack_channel = DangerPlugins.markdown_link_to_slack_room(slack_channel)
        else
          team_to_work_with = ruby_modularity_slack_channel
          team_to_work_with_slack_channel = ruby_modularity_slack_channel
        end

        link_to_doc = '[<ins>the Packwerk Cheatsheet</ins>](https://docs.google.com/document/d/1OGYqV1pt1r6g6LimCDs8RSIR7hBZ7BVO1yohk2Jnu0M/edit#heading=h.k5t08o3oedms)'
        disclaimer = "Before you run `bin/packwerk update-deprecations`, take a look at #{link_to_doc} and check out these quick suggestions:"
        get_help = "Need help? Join us in #{ruby_modularity_slack_channel} or see #{link_to_doc}."
        referencing_code_in_right_pack = "- Does the code you are writing live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{referencing_file}`"
        referenced_code_in_right_pack = "- Does #{constant_name} live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{constant_location}`"
        dependency_violation_message = "- Do we actually want to depend on #{constant_source_package_name}?\n  - If so, try `bin/packs add_dependency #{referencing_file_pack} #{constant_source_package_name}`\n  - If not, what can we change about the design so we do not have to depend on #{constant_source_package_name}?"
        privacy_violation_message = "- Does API in #{constant_source_package.name}/public support this use case?\n  - If not, can we work with #{team_to_work_with} to create and use a public API?\n  - If `#{constant_name}` should already be public, try `bin/packs make_public #{constant_location}`."
        constant_ownership = "- Owned by #{team_to_work_with} (Slack: #{team_to_work_with_slack_channel})"

        if violation_types.include?(Packwerk::ViolationType::Dependency) && violation_types.include?(Packwerk::ViolationType::Privacy)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock: + Dependency :knot:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
            - Owning pack: #{constant_source_package_name}
              #{constant_ownership}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{dependency_violation_message}
            #{privacy_violation_message}

            </details>

            _#{get_help}_
          MESSAGE
        elsif violation_types.include?(Packwerk::ViolationType::Dependency)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Dependency :knot:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
            - Owning pack: #{constant_source_package_name}
              #{constant_ownership}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{dependency_violation_message}

            </details>

            _#{get_help}_
          MESSAGE
        else # violation_types.include?(Packwerk::ViolationType::Privacy)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
            - Owning pack: #{constant_source_package_name}
              #{constant_ownership}

            <details><summary>Quick suggestions :bulb:</summary>

            #{disclaimer}
            #{referencing_code_in_right_pack}
            #{referenced_code_in_right_pack}
            #{privacy_violation_message}

            </details>

            _#{get_help}_
          MESSAGE
        end
      end
    end
  end
end
