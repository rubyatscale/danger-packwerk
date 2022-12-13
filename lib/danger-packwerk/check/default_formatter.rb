# typed: strict

require 'code_ownership'

module DangerPackwerk
  module Check
    class DefaultFormatter
      include OffensesFormatter
      extend T::Sig

      DEFAULT_UNKNOWN_OWNERSHIP_MESSAGE = "- This pack is unowned."

      class OwnershipInformation < T::Struct
        extend T::Sig

        const :owning_team, T.nilable(CodeTeams::Team)
        const :github_team, T.nilable(String)
        const :slack_channel, T.nilable(String)
        const :org_name, T.nilable(String)

        sig { params(package: ParsePackwerk::Package, org_name: String).returns(OwnershipInformation) }
        def self.for_package(package, org_name)
          team = CodeOwnership.for_package(package)

          if !team.nil?
            OwnershipInformation.new(
              owning_team: team,
              github_team: team.raw_hash.fetch('github', {}).fetch('team', nil),
              slack_channel: team.raw_hash.fetch('slack', {}).fetch('room_for_humans', nil),
              org_name: org_name
            )
          else
            OwnershipInformation.new
          end
        end

        sig { returns(String) }
        def ownership_copy
          github_team_flow_sensitive = github_team
          slack_channel_flow_sensitive = slack_channel

          if owning_team && github_team_flow_sensitive && slack_channel_flow_sensitive
            team_slack_link = markdown_link_to_slack_room(slack_channel_flow_sensitive)
            "- Owned by #{markdown_link_to_github_members_no_tag} (Slack: #{team_slack_link})"
          else
            DEFAULT_UNKNOWN_OWNERSHIP_MESSAGE
          end
        end


        sig { params(room: String).returns(String) }
        def markdown_link_to_slack_room(room)
          "[<ins>#{room}</ins>](https://slack.com/app_redirect?channel=#{room.delete('#')})"
        end

        #
        # Note this will NOT tag the team on Github, but it will link
        # to the mentioned team's members page. If you want to tag and
        # link the team, simply use the string and Github will handle it.
        #
        sig { returns(String) }
        def markdown_link_to_github_members_no_tag
          "[<ins>#{github_team}</ins>](https://github.com/orgs/#{org_name}/teams/#{T.must(github_team).gsub("@#{org_name}/", '')}/members)"
        end
      end

      sig do
        params(
          custom_help_message: T.nilable(String),
          unknown_ownership_message: T.nilable(String)
        ).void
      end
      def initialize(
        custom_help_message: nil,
        unknown_ownership_message: DEFAULT_UNKNOWN_OWNERSHIP_MESSAGE
      )
        @custom_help_message = custom_help_message
        @unknown_ownership_message = unknown_ownership_message
      end

      sig do
        override.params(
          offenses: T::Array[Packwerk::ReferenceOffense],
          repo_link: String,
          org_name: String,
        ).returns(String)
      end
      def format_offenses(offenses, repo_link, org_name)
        reference_offense = T.must(offenses.first)
        violation_types = offenses.map(&:violation_type)
        referencing_file = reference_offense.reference.relative_path
        referencing_file_pack = ParsePackwerk.package_from_path(referencing_file).name
        # We remove leading double colons as they feel like an implementation detail of packwerk.
        constant_name = reference_offense.reference.constant.name.delete_prefix('::')

        constant_source_package_name = reference_offense.reference.constant.package.name
        
        constant_location = reference_offense.reference.constant.location
        constant_source_package = T.must(ParsePackwerk.all.find { |p| p.name == constant_source_package_name })
        constant_source_package_ownership_info = OwnershipInformation.for_package(constant_source_package, org_name)

        disclaimer = "Before you run `bin/packwerk update-deprecations`, check out these quick suggestions:"
        referencing_code_in_right_pack = "- Does the code you are writing live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{referencing_file}`"
        referenced_code_in_right_pack = "- Does #{constant_name} live in the right pack?\n  - If not, try `bin/packs move packs/destination_pack #{constant_location}`"
        dependency_violation_message = "- Do we actually want to depend on #{constant_source_package_name}?\n  - If so, try `bin/packs add_dependency #{referencing_file_pack} #{constant_source_package_name}`\n  - If not, what can we change about the design so we do not have to depend on #{constant_source_package_name}?"
        team_to_work_with = constant_source_package_ownership_info.owning_team ? constant_source_package_ownership_info.markdown_link_to_github_members_no_tag : 'the pack owner'
        privacy_violation_message = "- Does API in #{constant_source_package.name}/public support this use case?\n  - If not, can we work with #{team_to_work_with} to create and use a public API?\n  - If `#{constant_name}` should already be public, try `bin/packs make_public #{constant_location}`."

        if violation_types.include?(Packwerk::ViolationType::Dependency) && violation_types.include?(Packwerk::ViolationType::Privacy)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock: + Dependency :knot:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
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
        elsif violation_types.include?(Packwerk::ViolationType::Dependency)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Dependency :knot:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
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
        else # violation_types.include?(Packwerk::ViolationType::Privacy)
          <<~MESSAGE
            **Packwerk Violation**
            - Type: Privacy :lock:
            - Constant: [<ins>`#{constant_name}`</ins>](#{repo_link}/blob/main/#{constant_location})
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
