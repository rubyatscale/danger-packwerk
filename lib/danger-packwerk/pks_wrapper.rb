# typed: strict

require 'open3'
require 'json'

module DangerPackwerk
  class PksWrapper
    extend T::Sig

    class PksBinaryNotFoundError < StandardError; end

    sig { params(files: T::Array[String]).returns(T::Array[PksOffense]) }
    def self.get_offenses_for_files(files)
      return [] if files.empty?

      stdout, stderr, _status = run_pks_check(files)

      if stderr.include?('command not found') || stderr.include?('No such file or directory')
        raise PksBinaryNotFoundError, 'pks binary not found. Please install pks to use this feature.'
      end

      PksOffense.from_json(stdout)
    end

    sig { params(files: T::Array[String]).returns([String, String, Process::Status]) }
    def self.run_pks_check(files)
      require 'shellwords'
      escaped_files = files.map { |f| Shellwords.escape(f) }.join(' ')
      command = "pks check --output-format json #{escaped_files}"
      Open3.capture3(command)
    end

    sig { returns(T::Boolean) }
    def self.pks_available?
      _, _, status = Open3.capture3('which', 'pks')
      !!status.success?
    end
  end
end
