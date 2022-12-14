# typed: strict # rubocop:disable Naming/FileName:
# frozen_string_literal: true

# This file exists so clients can call `require 'danger-packwerk'`
require 'sorbet-runtime'

module DangerPackwerk
  DEPRECATED_REFERENCES_PATTERN = T.let(/.*?deprecated_references\.yml\z/.freeze, Regexp)
  DEPENDENCY_VIOLATION_TYPE = 'dependency'
  PRIVACY_VIOLATION_TYPE = 'privacy'

  require 'danger-packwerk/danger_packwerk'
  require 'danger-packwerk/danger_deprecated_references_yml_changes'
  require 'danger-packwerk/check/offenses_formatter'
  require 'danger-packwerk/check/default_formatter'
  require 'danger-packwerk/update/offenses_formatter'
  require 'danger-packwerk/update/default_formatter'
end
