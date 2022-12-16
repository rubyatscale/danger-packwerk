# typed: strict

module DangerPackwerk
  # This class wraps packwerk to give us precisely what we want, which is the `Packwerk::ReferenceOffense` from a set of files.
  # Note that statically packwerk returns `Packwerk::Offense` from running `bin/packwerk check`. The two types of `Packwerk::Offense` are
  # `Packwerk::ReferenceOffense` and `Packwerk::Parsers::ParseResult`.`Packwerk::ReferenceOffense` inherits from `Packwerk::Offense`, and has more info than `Packwerk::Offense`.
  # `Packwerk::Parsers::ParseResult` is returned when there is a file parsing issue. We ignore ParseResult types as it's likely that other tests would break along with this Danger check.
  # and it is not the intent of this check to look for syntax errors in code.
  #
  # Also note that we would not need most of this class if there were two changes made to Packwerk:
  # 1) It did not raise if no checkable files were found (I think it might make more sense to just return successfully rather than raise). This occurs if the
  # input file list is excluded from the user's `exclude` list. In this case, check should return that no errors were found, since those files were not analyzed.
  # 2) If the CLI gave a way to get offenses from files without this somewhat hacky way of passing in a formatter that stores the offenses.
  class PackwerkWrapper
    extend T::Sig

    sig { params(files: T::Array[String]).returns(T::Array[Packwerk::ReferenceOffense]) }
    def self.get_offenses_for_files(files)
      formatter = OffensesAggregatorFormatter.new
      # This is mostly copied from exe/packwerk within the packwerk gem, but we use our own formatters
      ENV['RAILS_ENV'] = 'test'
      style = Packwerk::OutputStyles::Coloured.new
      cli = Packwerk::Cli.new(style: style, offenses_formatter: formatter)
      cli.execute_command(['check', *files])
      reference_offenses = formatter.aggregated_offenses.compact.select { |offense| offense.is_a?(Packwerk::ReferenceOffense) }
      T.cast(reference_offenses, T::Array[Packwerk::ReferenceOffense])
    rescue SystemExit => e
      # Packwerk should probably exit positively here rather than raising an error -- there should be no
      # errors if the user has excluded all files being checked.
      if e.message == 'No files found or given. Specify files or check the include and exclude glob in the config file.'
        []
      else
        raise
      end
    end

    #
    # This Packwerk formatter simply collects offenses. Ideally we could accomplish this by calling into public API of the CLI,
    # but right now this is the only way to get the raw offenses out of packwerk.
    #
    class OffensesAggregatorFormatter
      extend T::Sig
      include Packwerk::OffensesFormatter

      sig { returns(T::Array[Packwerk::Offense]) }
      attr_reader :aggregated_offenses

      sig { void }
      def initialize
        @aggregated_offenses = T.let([], T::Array[Packwerk::ReferenceOffense])
      end

      sig { override.params(offenses: T::Array[T.nilable(Packwerk::Offense)]).returns(String) }
      def show_offenses(offenses)
        @aggregated_offenses = T.unsafe(offenses)
        ''
      end

      # T.untyped should be Packwerk::OffenseCollection, but is currently private until
      # https://github.com/Shopify/packwerk/pull/289 merges
      sig { override.params(offense_collection: T.untyped, for_files: T::Set[String]).returns(String) }
      def show_stale_violations(offense_collection, for_files)
        ''
      end

      sig { override.params(strict_mode_violations: T::Array[::Packwerk::ReferenceOffense]).returns(::String) }
      def show_strict_mode_violations(strict_mode_violations)
        ''
      end

      sig { override.returns(::String) }
      def identifier
        'offenses_aggregator'
      end
    end
  end
end
