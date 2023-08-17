# typed: strict
# frozen_string_literal: true

require 'danger'
require 'packwerk'
require 'parse_packwerk'
require 'sorbet-runtime'
require 'danger-packwerk/packwerk_wrapper'
require 'danger-packwerk/private/git'

module DangerPackwerk
  # Note that Danger names the plugin (i.e. anything that inherits from `Danger::Plugin`) by taking the name of the class and gsubbing out "Danger"
  # Therefore this plugin is simply called "packwerk"
  class DangerPackwerk < Danger::Plugin
    extend T::Sig

    # We choose 15 because we want to err on the side of completeness and give users all of the information they need to help make their build pass,
    # especially given all violations should fail the build anyways.
    # We set a max (rather than unlimited) to avoid GitHub rate limiting and general spam if a PR does some sort of mass rename.
    DEFAULT_MAX_COMMENTS = 15
    OnFailure = T.type_alias { T.proc.params(offenses: T::Array[Packwerk::ReferenceOffense]).void }
    DEFAULT_ON_FAILURE = T.let(->(offenses) {}, OnFailure)
    DEFAULT_FAIL = false
    DEFAULT_FAILURE_MESSAGE = 'Packwerk violations were detected! Please resolve them to unblock the build.'
    DEFAULT_VIOLATION_TYPES = T.let([
                                      DEPENDENCY_VIOLATION_TYPE,
                                      PRIVACY_VIOLATION_TYPE
                                    ], T::Array[String])

    class CommentGroupingStrategy < ::T::Enum
      enums do
        PerConstantPerLocation = new
        PerConstantPerPack = new
      end
    end

    PerConstantPerPackGrouping = CommentGroupingStrategy::PerConstantPerPack

    sig do
      params(
        offenses_formatter: T.nilable(Check::OffensesFormatter),
        max_comments: Integer,
        fail_build: T::Boolean,
        failure_message: String,
        on_failure: OnFailure,
        violation_types: T::Array[String],
        grouping_strategy: CommentGroupingStrategy,
        root_path: T.nilable(String)
      ).void
    end
    def check(
      offenses_formatter: nil,
      max_comments: DEFAULT_MAX_COMMENTS,
      fail_build: DEFAULT_FAIL,
      failure_message: DEFAULT_FAILURE_MESSAGE,
      on_failure: DEFAULT_ON_FAILURE,
      violation_types: DEFAULT_VIOLATION_TYPES,
      grouping_strategy: CommentGroupingStrategy::PerConstantPerLocation,
      root_path: nil
    )
      offenses_formatter ||= Check::DefaultFormatter.new
      repo_link = github.pr_json[:base][:repo][:html_url]
      org_name = github.pr_json[:base][:repo][:owner][:login]

      # This is important because by default, Danger will leave a concantenated list of all its messages if it can't find a commentable place in the
      # diff to leave its message. This is an especially bad UX because it will be a huge wall of text not connected to the source of the issue.
      # Furthermore, dismissing these ensures that something like moving a file from pack to pack does not trigger the danger message. That is,
      # the danger message will only be triggered by actual code that someone has actually written in their PR.
      # Another example would be if someone changes the list of dependencies of a package (e.g. to resolve a cyclic dependency). This would not
      # trigger the warning message, which is good, since we only want to trigger on new code.
      github.dismiss_out_of_range_messages

      git_filesystem = Private::GitFilesystem.new(git: git, root: root_path || '')

      # https://github.com/danger/danger/blob/eca19719d3e585fe1cc46bc5377f9aa955ebf609/lib/danger/danger_core/plugins/dangerfile_git_plugin.rb#L80
      renamed_files_after = git_filesystem.renamed_files.map { |f| f[:after] }

      targeted_files = (git_filesystem.modified_files + git_filesystem.added_files + renamed_files_after).select do |f|
        path = Pathname.new(f)

        # We probably want to check the `include` key of `packwerk.yml`. By default, this value is "**/*.{rb,rake,erb}",
        # so we hardcode this in for now. If this blocks a user, we can take that opportunity to read from `packwerk.yml`.
        extension_is_targeted = ['.erb', '.rake', '.rb'].include?(path.extname)

        # If a file has been modified via a rename, then `git.modified_files` will return an array that includes that file's *original* name.
        # Packwerk will ignore input files that do not exist, and when the PR only contains renamed Ruby files, that means packwerk check works
        # off of an empty list. It's default behavior in that case is to scan *all* files, which can lead to abnormally long run times.
        # To avoid this, we gracefully return if there are no targeted files.
        # To avoid false negatives, we also look at renamed files after (above)
        file_exists = path.exist?

        extension_is_targeted && file_exists
      end

      return if targeted_files.empty?

      current_comment_count = 0

      packwerk_reference_offenses = PackwerkWrapper.get_offenses_for_files(targeted_files.to_a).compact

      renamed_files = git_filesystem.renamed_files.map { |before_after_file| before_after_file[:after] }

      packwerk_reference_offenses_to_care_about = packwerk_reference_offenses.reject do |packwerk_reference_offense|
        constant_name = packwerk_reference_offense.reference.constant.name
        filepath_that_defines_this_constant = Private.constant_resolver.resolve(constant_name)&.location
        # Ignore references that have been renamed
        renamed_files.include?(filepath_that_defines_this_constant) ||
          # Ignore violations that are not in the allow-list of violation types to leave comments for
          !violation_types.include?(packwerk_reference_offense.violation_type)
      end

      # We group by the constant name, line number, and reference path. Any offenses with these same values should only differ on what type of violation
      # they are (privacy or dependency). We put privacy and dependency violation messages in the same comment since they would occur on the same line.
      packwerk_reference_offenses_to_care_about.group_by do |packwerk_reference_offense|
        case grouping_strategy
        when CommentGroupingStrategy::PerConstantPerLocation
          [
            packwerk_reference_offense.reference.constant.name,
            packwerk_reference_offense.location&.line,
            packwerk_reference_offense.reference.relative_path
          ]
        when CommentGroupingStrategy::PerConstantPerPack
          [
            packwerk_reference_offense.reference.constant.name,
            ParsePackwerk.package_from_path(packwerk_reference_offense.reference.relative_path)
          ]
        else
          T.absurd(grouping_strategy)
        end
      end.each do |_group, unique_packwerk_reference_offenses|
        break if current_comment_count >= max_comments

        current_comment_count += 1

        reference_offense = T.must(unique_packwerk_reference_offenses.first)
        line_number = reference_offense.location&.line
        referencing_file = reference_offense.reference.relative_path

        message = offenses_formatter.format_offenses(unique_packwerk_reference_offenses, repo_link, org_name)
        markdown(message, file: git_filesystem.convert_to_filesystem(referencing_file), line: line_number)
      end

      if current_comment_count > 0
        fail(failure_message) if fail_build

        on_failure.call(packwerk_reference_offenses)
      end
    end
  end
end
