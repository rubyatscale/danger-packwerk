# typed: strict # rubocop:disable Naming/FileName:
# frozen_string_literal: true

# This file exists so clients can call `require 'danger-packwerk'`
require 'sorbet-runtime'

module DangerPackwerk
  DEPRECATED_REFERENCES_PATTERN = T.let(/.*?deprecated_references\.yml\z/.freeze, Regexp)

  require 'danger-packwerk/danger_packwerk'
  require 'danger-packwerk/danger_deprecated_references_yml_changes'
end
