# typed: true

class Danger::DangerfileGitHubPlugin < ::Danger::Plugin
  def initialize(dangerfile); end

  def api; end
  def base_commit; end
  def branch_for_base; end
  def branch_for_head; end
  def dismiss_out_of_range_messages(dismiss = T.unsafe(nil)); end
  def head_commit; end
  def html_link(paths, full_path: T.unsafe(nil)); end
  def mr_author; end
  def mr_body; end
  def mr_json; end
  def mr_labels; end
  def mr_title; end
  def pr_author; end
  def pr_body; end
  def pr_diff; end
  def pr_draft?; end
  def pr_json; end
  def pr_labels; end
  def pr_title; end
  def review; end

  private

  def create_link(href, text); end

  class << self
    def instance_name; end
    def new(dangerfile); end
  end
end

class Danger::CI
  def initialize(_env); end

  def pull_request_id; end
  def pull_request_id=(_arg0); end
  def repo_slug; end
  def repo_slug=(_arg0); end
  def repo_url; end
  def repo_url=(_arg0); end
  def supported_request_sources; end
  def supported_request_sources=(_arg0); end
  def supports?(request_source); end

  class << self
    def available_ci_sources; end
    def inherited(child_class); end
    def validates_as_ci?(_env); end
    def validates_as_pr?(_env); end
  end
end

class Danger::LocalGitRepo < ::Danger::CI
  def initialize(env = T.unsafe(nil)); end

  def base_commit; end
  def base_commit=(_arg0); end
  def git; end
  def head_commit; end
  def head_commit=(_arg0); end
  def run_git(command); end
  def supported_request_sources; end

  private

  def commits; end
  def find_pull_request(env); end
  def find_remote_info(env); end
  def found_pull_request; end
  def given_pull_request_url?(env); end
  def missing_remote_error_message; end
  def raise_error_for_missing_remote; end
  def remote_info; end
  def sha; end

  class << self
    def validates_as_ci?(env); end
    def validates_as_pr?(_env); end
  end
end


class Danger::DangerfileGitPlugin < ::Danger::Plugin
  def initialize(dangerfile); end

  def added_files; end
  def commits; end
  def deleted_files; end
  def deletions; end
  def diff; end
  def diff_for_file(file); end
  def info_for_file(file); end
  def insertions; end
  def lines_of_code; end
  def modified_files; end
  def renamed_files; end
  def tags; end

  class << self
    def instance_name; end
  end
end


class Danger::Plugin
  sig { returns(Danger::DangerfileGitHubPlugin) }
  def github; end

  sig { returns(Danger::DangerfileGitPlugin) }
  def git; end

  def markdown(message, file:, line:); end
end

class Danger::Dangerfile; end
module Danger::EnvironmentManager; end
module DangerHelpers::Cork::Board; end
