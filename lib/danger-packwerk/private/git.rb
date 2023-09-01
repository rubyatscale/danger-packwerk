# typed: strict

require 'code_ownership'
require 'packs'

# In order to support running danger-packwerk from a non-root filepath, we need
# to wrap some git functions in filesystem wrappers: packwerk runs relative to
# the rails app root, whereas git returns paths on the actual filesystem.
module DangerPackwerk
  module Private
    class GitFilesystem < T::Struct
      extend T::Sig

      const :git, Danger::DangerfileGitPlugin
      const :root, String

      sig { returns(T::Array[{ after: String, before: String }]) }
      def renamed_files
        @git.renamed_files.map do |f|
          {
            after: convert_file_from_filesystem(f[:after]),
            before: convert_file_from_filesystem(f[:before])
          }
        end
      end

      sig { returns(T::Array[String]) }
      def modified_files
        convert_from_filesystem(@git.modified_files.to_a)
      end

      sig { returns(T::Array[String]) }
      def deleted_files
        convert_from_filesystem(@git.deleted_files.to_a)
      end

      sig { returns(T::Array[String]) }
      def added_files
        convert_from_filesystem(@git.added_files.to_a)
      end

      sig { params(filename_on_disk: String).returns(::Git::Diff::DiffFile) }
      def diff(filename_on_disk)
        @git.diff[filename_on_disk]
      end

      sig { params(path: String).returns(String) }
      def convert_to_filesystem(path)
        Pathname(@root).join(path).to_s
      end

      private

      sig { params(files: T::Array[String]).returns(T::Array[String]) }
      def convert_from_filesystem(files)
        files.map { |f| convert_file_from_filesystem(f) }
      end

      sig { params(file: String).returns(String) }
      def convert_file_from_filesystem(file)
        Pathname(file).relative_path_from(@root).to_s
      end
    end
  end
end
