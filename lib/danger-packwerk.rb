# typed: strict # rubocop:disable Naming/FileName:
# frozen_string_literal: true

# This file exists so clients can call `require 'danger-packwerk'`
require 'sorbet-runtime'

module DangerPackwerk
  PACKAGE_TODO_PATTERN = T.let(/.*?package_todo\.yml\z/, Regexp)
  DEPENDENCY_VIOLATION_TYPE = 'dependency'
  PRIVACY_VIOLATION_TYPE = 'privacy'

  require 'danger-packwerk/danger_packwerk'
  require 'danger-packwerk/danger_package_todo_yml_changes'
  require 'danger-packwerk/check/offenses_formatter'
  require 'danger-packwerk/check/default_formatter'
  require 'danger-packwerk/update/offenses_formatter'
  require 'danger-packwerk/update/default_formatter'
  require 'danger-packwerk/pks_offense'
  require 'danger-packwerk/pks_wrapper'
end
