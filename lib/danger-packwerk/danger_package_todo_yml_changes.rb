# typed: strict
# frozen_string_literal: true

require 'danger'
require 'sorbet-runtime'
require 'danger-packwerk/private'
require 'danger-packwerk/basic_reference_offense'
require 'danger-packwerk/violation_diff'
require 'open3'

module DangerPackwerk
  class DangerPackageTodoYmlChanges < Danger::Plugin
    extend T::Sig

    # We choose 5 here because violation additions tend to fall into a bimodal distribution, where most PRs only add a handful (<10) of new violations,
    # but there are some that do a rename of an often-used variable, which can change hundreds of violations.
    # Therefore we hope to capture the majority case of people making changes to code while not spamming PRs that do a big rename.
    # We set a max (rather than unlimited) to avoid GitHub rate limiting and general spam if a PR does some sort of mass rename.
    DEFAULT_MAX_COMMENTS = 5
    BeforeComment = T.type_alias { T.proc.params(violation_diff: ViolationDiff, changed_package_todo_ymls: T::Array[String]).void }
    DEFAULT_BEFORE_COMMENT = T.let(->(violation_diff, changed_package_todo_ymls) {}, BeforeComment)
    DEFAULT_VIOLATION_TYPES = T.let([
                                      DEPENDENCY_VIOLATION_TYPE,
                                      PRIVACY_VIOLATION_TYPE
                                    ], T::Array[String])

    sig do
      params(
        offenses_formatter: T.nilable(Update::OffensesFormatter),
        before_comment: BeforeComment,
        max_comments: Integer,
        violation_types: T::Array[String],
        root_path: T.nilable(String)
      ).void
    end
    def check(
      offenses_formatter: nil,
      before_comment: DEFAULT_BEFORE_COMMENT,
      max_comments: DEFAULT_MAX_COMMENTS,
      violation_types: DEFAULT_VIOLATION_TYPES,
      root_path: nil
    )
      offenses_formatter ||= Update::DefaultFormatter.new
      repo_link = github.pr_json[:base][:repo][:html_url]
      org_name = github.pr_json[:base][:repo][:owner][:login]

      git_filesystem = Private::GitFilesystem.new(git: git, root: root_path || '')
      changed_package_todo_ymls = (git_filesystem.modified_files + git_filesystem.added_files + git_filesystem.deleted_files).grep(PACKAGE_TODO_PATTERN)

      violation_diff = get_violation_diff(violation_types, root_path: root_path)

      before_comment.call(
        violation_diff,
        changed_package_todo_ymls.to_a
      )

      current_comment_count = 0

      violation_diff.added_violations.group_by(&:class_name).each do |_class_name, violations|
        break if current_comment_count >= max_comments

        location = T.must(violations.first).file_location

        markdown(
          offenses_formatter.format_offenses(violations, repo_link, org_name),
          line: location.line_number,
          file: git_filesystem.convert_to_filesystem(location.file)
        )

        current_comment_count += 1
      end
    end

    sig do
      params(
        violation_types: T::Array[String],
        root_path: T.nilable(String)
      ).returns(ViolationDiff)
    end
    def get_violation_diff(violation_types, root_path: nil)
      git_filesystem = Private::GitFilesystem.new(git: git, root: root_path || '')

      added_violations, removed_violations = Private::TodoYmlChanges.get_reference_offenses(
        violation_types, git_filesystem
      )

      ViolationDiff.new(
        added_violations: added_violations,
        removed_violations: removed_violations
      )
    end
  end
end
