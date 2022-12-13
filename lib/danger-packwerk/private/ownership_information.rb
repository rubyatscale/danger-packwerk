# typed: strict

require 'code_ownership'

module DangerPackwerk
  module Private
    class OwnershipInformation < T::Struct
      extend T::Sig

      DEFAULT_UNKNOWN_OWNERSHIP_MESSAGE = "- This pack is unowned."

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
          team_slack_link = markdown_link_to_slack_room
          "- Owned by #{markdown_link_to_github_members_no_tag} (Slack: #{team_slack_link})"
        else
          DEFAULT_UNKNOWN_OWNERSHIP_MESSAGE
        end
      end


      sig { returns(String) }
      def markdown_link_to_slack_room
        "[<ins>#{slack_channel}</ins>](https://slack.com/app_redirect?channel=#{T.must(slack_channel).delete('#')})"
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
  end
end
