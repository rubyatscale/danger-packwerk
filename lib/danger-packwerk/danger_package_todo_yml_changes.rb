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
      added_violations = T.let([], T::Array[BasicReferenceOffense])
      removed_violations = T.let([], T::Array[BasicReferenceOffense])

      git_filesystem = Private::GitFilesystem.new(git: git, root: root_path || '')
      git_filesystem.added_files.grep(PACKAGE_TODO_PATTERN).each do |added_package_todo_yml_file|
        # Since the file is added, we know on the base commit there are no violations related to this pack,
        # and that all violations from this file are new
        added_violations += BasicReferenceOffense.from(added_package_todo_yml_file)
      end

      git_filesystem.deleted_files.grep(PACKAGE_TODO_PATTERN).each do |deleted_package_todo_yml_file|
        # Since the file is deleted, we know on the HEAD commit there are no violations related to this pack,
        # and that all violations from this file are deleted
        deleted_violations = get_violations_before_patch_for(git_filesystem, deleted_package_todo_yml_file)
        removed_violations += deleted_violations
      end

      # The format for git.renamed_files is a T::Array[{after: "some/path/new", before: "some/path/old"}]
      renamed_files_before = git_filesystem.renamed_files.map { |before_after_file| before_after_file[:before] }
      renamed_files_after = git_filesystem.renamed_files.map { |before_after_file| before_after_file[:after] }

      git_filesystem.modified_files.grep(PACKAGE_TODO_PATTERN).each do |modified_package_todo_yml_file|
        # We skip over modified files if one of the modified files is a renamed `package_todo.yml` file.
        # This allows us to rename packs while ignoring "new violations" in those renamed packs.
        next if renamed_files_before.include?(modified_package_todo_yml_file)

        head_commit_violations = BasicReferenceOffense.from(modified_package_todo_yml_file)
        base_commit_violations = get_violations_before_patch_for(git_filesystem, modified_package_todo_yml_file)
        added_violations += head_commit_violations - base_commit_violations
        removed_violations += base_commit_violations - head_commit_violations
      end

      #
      # This implementation creates some false negatives:
      # That is – it doesn't capture some cases:
      # 1) A file has been renamed without renaming a constant.
      # That can happen if we change only the autoloaded portion of a filename.
      # For example: `packs/foo/app/services/my_class.rb` (defines: `MyClass`)
      # is changed to `packs/foo/app/public/my_class.rb` (still defines: `MyClass`)
      #
      # This implementation also doesn't cover these false positives:
      # That is – it leaves a comment when it should not.
      # 1) A CONSTANT within a class or module has been renamed.
      # e.g. `class MyClass; MY_CONSTANT = 1; end` becomes `class MyClass; RENAMED_CONSTANT = 1; end`
      # We would not detect based on file renames that `MY_CONSTANT` has been renamed.
      #
      renamed_constants = []

      added_violations.each do |violation|
        filepath_that_defines_this_constant = Private.constant_resolver.resolve(violation.class_name)&.location
        renamed_constants << violation.class_name if renamed_files_after.include?(filepath_that_defines_this_constant)
      end

      relevant_added_violations = added_violations.reject do |violation|
        renamed_files_after.include?(violation.file) ||
          renamed_constants.include?(violation.class_name) ||
          !violation_types.include?(violation.type)
      end

      relevant_removed_violations = removed_violations.select do |violation|
        violation_types.include?(violation.type)
      end

      ViolationDiff.new(
        added_violations: relevant_added_violations,
        removed_violations: relevant_removed_violations
      )
    end

    private

    sig do
      params(
        git_filesystem: Private::GitFilesystem,
        package_todo_yml_file: String
      ).returns(T::Array[BasicReferenceOffense])
    end
    def get_violations_before_patch_for(git_filesystem, package_todo_yml_file)
      # The strategy to get the violations before this PR is to reverse the patch on each `package_todo.yml`.
      # A previous strategy attempted to use `git merge-base --fork-point`, but there are many situations where it returns
      # empty values. That strategy is fickle because it depends on the state of the `reflog` within the CI suite, which appears
      # to not be reliable to depend on.
      #
      # Instead, just inverting the patch should hopefully provide a more reliable way to figure out what was the state of the file before
      # the PR without needing to use git commands that interpret the branch history based on local git history.
      #
      # We apply the patch to the original file so that we can seamlessly reverse the patch applied to that file (since patches are coupled to
      # the files they modify). After parsing the violations from that `package_todo.yml` file with the patch reversed,
      # we use a temporary copy of the original file to rewrite to it with the original contents.
      # Note that practically speaking, we don't need to rewrite the original contents (since we already fetched the
      # original contents above and the CI file system should be ephemeral). However, we do this anyways in case we later change these
      # assumptions, or another client's environment is different and expects these files not to be mutated.

      # Keep track of the original file contents. If the original file has been deleted, then we delete the file after inverting the patch at the end, rather than rewriting it.
      package_todo_yml_file_copy = (File.read(package_todo_yml_file) if File.exist?(package_todo_yml_file))

      Tempfile.create do |patch_file|
        # Normally we'd use `git.diff_for_file(package_todo_yml_file).patch` here, but there is a bug where it does not work for deleted files yet.
        # I have a fix for that here: https://github.com/danger/danger/pull/1357
        # Until that lands, I'm just using the underlying implementation of that method to get the diff for a file.
        # Note that I might want to use a safe escape operator, `&.patch` and return gracefully if the patch cannot be found.
        # However I'd be interested in why that ever happens, so for now going to proceed as is.
        # (Note that better yet we'd have observability into these so I can just log under those circumstances rather than surfacing an error to the user,
        # but we don't have that quite yet.)
        package_todo_filesystem_path = git_filesystem.convert_to_filesystem(package_todo_yml_file)
        patch_for_file = git_filesystem.diff(package_todo_filesystem_path).patch
        # This appears to be a known issue that patches require new lines at the end. It seems like this is an issue with Danger that
        # it gives us a patch without a newline.
        # https://stackoverflow.com/questions/18142870/git-error-fatal-corrupt-patch-at-line-36
        patch_file << "#{patch_for_file}\n"
        patch_file.rewind
        # https://git-scm.com/docs/git-apply
        _stdout, _stderr, _status = Open3.capture3("git apply --reverse #{patch_file.path}")
        # https://www.rubyguides.com/2019/05/ruby-tempfile/
        BasicReferenceOffense.from(package_todo_yml_file)
      end
    ensure
      if package_todo_yml_file_copy
        File.write(package_todo_yml_file, package_todo_yml_file_copy)
      else
        File.delete(package_todo_yml_file)
      end
    end
  end
end
