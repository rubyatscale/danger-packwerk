# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `packwerk` gem.
# Please instead update this file by running `bin/tapioca gem packwerk`.

module Packwerk
  extend ::ActiveSupport::Autoload
end

module Packwerk::ApplicationLoadPaths
  class << self
    sig { returns(T::Array[::String]) }
    def extract_application_autoload_paths; end

    sig { params(root: ::String, environment: ::String).returns(T::Array[::String]) }
    def extract_relevant_paths(root, environment); end

    sig do
      params(
        all_paths: T::Array[::String],
        bundle_path: ::Pathname,
        rails_root: ::Pathname
      ).returns(T::Array[::Pathname])
    end
    def filter_relevant_paths(all_paths, bundle_path: T.unsafe(nil), rails_root: T.unsafe(nil)); end

    sig { params(paths: T::Array[::Pathname], rails_root: ::Pathname).returns(T::Array[::String]) }
    def relative_path_strings(paths, rails_root: T.unsafe(nil)); end

    private

    sig { params(paths: T::Array[T.untyped]).void }
    def assert_load_paths_present(paths); end

    sig { params(root: ::String, environment: ::String).void }
    def require_application(root, environment); end
  end
end

class Packwerk::ApplicationValidator
  sig { params(config_file_path: ::String, configuration: ::Packwerk::Configuration, environment: ::String).void }
  def initialize(config_file_path:, configuration:, environment:); end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_acyclic_graph; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_all; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_application_structure; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_package_manifest_paths; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_package_manifest_syntax; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_package_manifests_for_privacy; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_root_package_exists; end

  sig { returns(::Packwerk::ApplicationValidator::Result) }
  def check_valid_package_dependencies; end

  private

  sig do
    params(
      constants: T.untyped,
      config_file_path: ::String
    ).returns(T::Array[::Packwerk::ApplicationValidator::Result])
  end
  def assert_constants_can_be_loaded(constants, config_file_path); end

  sig { params(cycles: T.untyped).returns(T::Array[::String]) }
  def build_cycle_strings(cycles); end

  sig do
    params(
      name: T.untyped,
      location: T.untyped,
      config_file_path: T.untyped
    ).returns(::Packwerk::ApplicationValidator::Result)
  end
  def check_private_constant_location(name, location, config_file_path); end

  sig { params(list: T.untyped).returns(T.untyped) }
  def format_yaml_strings(list); end

  sig { params(path: T.untyped).returns(T::Boolean) }
  def invalid_package_path?(path); end

  sig do
    params(
      results: T::Array[::Packwerk::ApplicationValidator::Result],
      separator: ::String,
      errors_headline: ::String
    ).returns(::Packwerk::ApplicationValidator::Result)
  end
  def merge_results(results, separator: T.unsafe(nil), errors_headline: T.unsafe(nil)); end

  sig { returns(T.any(::String, T::Array[::String])) }
  def package_glob; end

  sig { params(glob_pattern: T.any(::String, T::Array[::String])).returns(T::Array[::String]) }
  def package_manifests(glob_pattern = T.unsafe(nil)); end

  sig { params(setting: T.untyped).returns(T.untyped) }
  def package_manifests_settings_for(setting); end

  sig { params(name: T.untyped, config_file_path: T.untyped).returns(::Packwerk::ApplicationValidator::Result) }
  def private_constant_unresolvable(name, config_file_path); end

  sig { params(path: ::String).returns(::Pathname) }
  def relative_path(path); end

  sig { params(paths: T::Array[::String]).returns(T::Array[::Pathname]) }
  def relative_paths(paths); end
end

class Packwerk::ApplicationValidator::Result < ::T::Struct
  const :error_value, T.nilable(::String)
  const :ok, T::Boolean

  sig { returns(T::Boolean) }
  def ok?; end

  class << self
    def inherited(s); end
  end
end

class Packwerk::AssociationInspector
  include ::Packwerk::ConstantNameInspector

  sig do
    params(
      inflector: T.class_of(ActiveSupport::Inflector),
      custom_associations: T.any(T::Array[::Symbol], T::Set[::Symbol])
    ).void
  end
  def initialize(inflector:, custom_associations: T.unsafe(nil)); end

  sig { override.params(node: ::AST::Node, ancestors: T::Array[::AST::Node]).returns(T.nilable(::String)) }
  def constant_name_from_node(node, ancestors:); end

  private

  sig { params(node: ::AST::Node).returns(T::Boolean) }
  def association?(node); end

  sig { params(arguments: T::Array[::AST::Node]).returns(T.nilable(T.any(::String, ::Symbol))) }
  def association_name(arguments); end

  sig { params(arguments: T::Array[::AST::Node]).returns(T.nilable(::AST::Node)) }
  def custom_class_name(arguments); end
end

Packwerk::AssociationInspector::CustomAssociations = T.type_alias { T.any(T::Array[::Symbol], T::Set[::Symbol]) }
Packwerk::AssociationInspector::RAILS_ASSOCIATIONS = T.let(T.unsafe(nil), Set)

class Packwerk::Cache
  sig { params(enable_cache: T::Boolean, cache_directory: ::Pathname, config_path: T.nilable(::String)).void }
  def initialize(enable_cache:, cache_directory:, config_path:); end

  sig { void }
  def bust_cache!; end

  sig { params(contents: ::String, contents_key: ::Symbol).void }
  def bust_cache_if_contents_have_changed(contents, contents_key); end

  sig { void }
  def bust_cache_if_inflections_have_changed!; end

  sig { void }
  def bust_cache_if_packwerk_yml_has_changed!; end

  sig { void }
  def create_cache_directory!; end

  sig { params(file: ::String).returns(::String) }
  def digest_for_file(file); end

  sig { params(str: ::String).returns(::String) }
  def digest_for_string(str); end

  sig do
    params(
      file_path: ::String,
      block: T.proc.returns(T::Array[::Packwerk::UnresolvedReference])
    ).returns(T::Array[::Packwerk::UnresolvedReference])
  end
  def with_cache(file_path, &block); end
end

Packwerk::Cache::CACHE_SHAPE = T.type_alias { T::Hash[::String, ::Packwerk::Cache::CacheContents] }

class Packwerk::Cache::CacheContents < ::T::Struct
  const :file_contents_digest, ::String
  const :unresolved_references, T::Array[::Packwerk::UnresolvedReference]

  sig { returns(::String) }
  def serialize; end

  class << self
    sig { params(serialized_cache_contents: ::String).returns(::Packwerk::Cache::CacheContents) }
    def deserialize(serialized_cache_contents); end

    def inherited(s); end
  end
end

class Packwerk::Cli
  sig do
    params(
      configuration: T.nilable(::Packwerk::Configuration),
      out: T.any(::IO, ::StringIO),
      err_out: T.any(::IO, ::StringIO),
      environment: ::String,
      style: ::Packwerk::OutputStyle,
      offenses_formatter: T.nilable(::Packwerk::OffensesFormatter)
    ).void
  end
  def initialize(configuration: T.unsafe(nil), out: T.unsafe(nil), err_out: T.unsafe(nil), environment: T.unsafe(nil), style: T.unsafe(nil), offenses_formatter: T.unsafe(nil)); end

  sig { params(args: T::Array[::String]).returns(T::Boolean) }
  def execute_command(args); end

  sig { params(args: T::Array[::String]).returns(T.noreturn) }
  def run(args); end

  private

  sig { returns(::Packwerk::ApplicationValidator) }
  def checker; end

  sig do
    params(
      relative_file_paths: T::Array[::String],
      ignore_nested_packages: T::Boolean
    ).returns(T::Array[::String])
  end
  def fetch_files_to_process(relative_file_paths, ignore_nested_packages); end

  sig { returns(T::Boolean) }
  def generate_configs; end

  sig { returns(T::Boolean) }
  def init; end

  sig { params(result: ::Packwerk::ApplicationValidator::Result).void }
  def list_validation_errors(result); end

  sig { params(result: ::Packwerk::Result).returns(T::Boolean) }
  def output_result(result); end

  sig { params(params: T.untyped).returns(::Packwerk::ParseRun) }
  def parse_run(params); end

  sig { params(_paths: T::Array[::String]).returns(T::Boolean) }
  def validate(_paths); end
end

class Packwerk::Configuration
  def initialize(configs = T.unsafe(nil), config_path: T.unsafe(nil)); end

  def cache_directory; end
  def cache_enabled?; end
  def config_path; end
  def custom_associations; end
  def exclude; end
  def include; end
  def load_paths; end
  def package_paths; end
  def parallel?; end
  def root_path; end

  class << self
    def from_path(path = T.unsafe(nil)); end

    private

    def from_packwerk_config(path); end
  end
end

Packwerk::Configuration::DEFAULT_CONFIG_PATH = T.let(T.unsafe(nil), String)
Packwerk::Configuration::DEFAULT_EXCLUDE_GLOBS = T.let(T.unsafe(nil), Array)
Packwerk::Configuration::DEFAULT_INCLUDE_GLOBS = T.let(T.unsafe(nil), Array)

class Packwerk::ConstNodeInspector
  include ::Packwerk::ConstantNameInspector

  sig { override.params(node: ::AST::Node, ancestors: T::Array[::AST::Node]).returns(T.nilable(::String)) }
  def constant_name_from_node(node, ancestors:); end

  private

  sig { params(node: ::AST::Node, parent: ::AST::Node).returns(T.nilable(T::Boolean)) }
  def constant_in_module_or_class_definition?(node, parent:); end

  sig { params(ancestors: T::Array[::AST::Node]).returns(::String) }
  def fully_qualify_constant(ancestors); end

  sig { params(parent: T.nilable(::AST::Node)).returns(T::Boolean) }
  def root_constant?(parent); end
end

class Packwerk::ConstantDiscovery
  sig { params(constant_resolver: ::ConstantResolver, packages: Packwerk::PackageSet).void }
  def initialize(constant_resolver:, packages:); end

  sig do
    params(
      const_name: ::String,
      current_namespace_path: T.nilable(T::Array[::String])
    ).returns(T.nilable(::Packwerk::ConstantDiscovery::ConstantContext))
  end
  def context_for(const_name, current_namespace_path: T.unsafe(nil)); end

  sig { params(path: ::String).returns(::Packwerk::Package) }
  def package_from_path(path); end
end

class Packwerk::ConstantDiscovery::ConstantContext < ::Struct
  def location; end
  def location=(_); end
  def name; end
  def name=(_); end
  def package; end
  def package=(_); end
  def public?; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

module Packwerk::ConstantNameInspector
  interface!

  sig { abstract.params(node: ::AST::Node, ancestors: T::Array[::AST::Node]).returns(T.nilable(::String)) }
  def constant_name_from_node(node, ancestors:); end
end

class Packwerk::Debug
  class << self
    sig { params(out: ::String).void }
    def out(out); end
  end
end

class Packwerk::DeprecatedReferences
  sig { params(package: ::Packwerk::Package, filepath: ::String).void }
  def initialize(package, filepath); end

  sig { params(reference: ::Packwerk::Reference, violation_type: ::Packwerk::ViolationType).returns(T::Boolean) }
  def add_entries(reference, violation_type); end

  sig { void }
  def dump; end

  sig { params(reference: ::Packwerk::Reference, violation_type: ::Packwerk::ViolationType).returns(T::Boolean) }
  def listed?(reference, violation_type:); end

  sig { returns(T::Boolean) }
  def stale_violations?; end

  private

  sig { returns(T::Hash[::String, T.untyped]) }
  def deprecated_references; end

  sig { params(filepath: ::String).returns(T::Hash[::String, T.untyped]) }
  def load_yaml(filepath); end

  sig { returns(T::Hash[::String, T.untyped]) }
  def prepare_entries_for_dump; end
end

Packwerk::DeprecatedReferences::ENTRIES_TYPE = T.type_alias { T::Hash[::String, T.untyped] }

class Packwerk::FileProcessor
  sig do
    params(
      node_processor_factory: ::Packwerk::NodeProcessorFactory,
      cache: ::Packwerk::Cache,
      parser_factory: T.nilable(::Packwerk::Parsers::Factory)
    ).void
  end
  def initialize(node_processor_factory:, cache:, parser_factory: T.unsafe(nil)); end

  sig do
    params(
      absolute_file: ::String
    ).returns(T::Array[T.any(::Packwerk::Offense, ::Packwerk::UnresolvedReference)])
  end
  def call(absolute_file); end

  private

  sig { params(absolute_file: ::String, parser: ::Packwerk::Parsers::ParserInterface).returns(T.untyped) }
  def parse_into_ast(absolute_file, parser); end

  sig { params(file_path: ::String).returns(T.nilable(::Packwerk::Parsers::ParserInterface)) }
  def parser_for(file_path); end

  sig { params(node: ::Parser::AST::Node, absolute_file: ::String).returns(T::Array[::Packwerk::UnresolvedReference]) }
  def references_from_ast(node, absolute_file); end
end

class Packwerk::FileProcessor::UnknownFileTypeResult < ::Packwerk::Offense
  sig { params(file: ::String).void }
  def initialize(file:); end
end

class Packwerk::FilesForProcessing
  sig do
    params(
      relative_file_paths: T::Array[::String],
      configuration: ::Packwerk::Configuration,
      ignore_nested_packages: T::Boolean
    ).void
  end
  def initialize(relative_file_paths, configuration, ignore_nested_packages); end

  sig { returns(T::Array[::String]) }
  def files; end

  private

  sig { params(relative_globs: T::Array[::String]).returns(T::Array[::String]) }
  def absolute_files_for_globs(relative_globs); end

  sig { returns(T::Array[::String]) }
  def configured_excluded_files; end

  sig { returns(T::Array[::String]) }
  def configured_included_files; end

  sig { returns(T::Array[::String]) }
  def custom_files; end

  sig { params(absolute_file_path: ::String).returns(T::Array[::String]) }
  def custom_included_files(absolute_file_path); end

  class << self
    sig do
      params(
        relative_file_paths: T::Array[::String],
        configuration: ::Packwerk::Configuration,
        ignore_nested_packages: T::Boolean
      ).returns(T::Array[::String])
    end
    def fetch(relative_file_paths:, configuration:, ignore_nested_packages: T.unsafe(nil)); end
  end
end

module Packwerk::Formatters
  extend ::ActiveSupport::Autoload
end

class Packwerk::Formatters::OffensesFormatter
  include ::Packwerk::OffensesFormatter

  sig { params(style: ::Packwerk::OutputStyle).void }
  def initialize(style: T.unsafe(nil)); end

  sig { override.params(offenses: T::Array[T.nilable(::Packwerk::Offense)]).returns(::String) }
  def show_offenses(offenses); end

  sig { override.params(offense_collection: ::Packwerk::OffenseCollection).returns(::String) }
  def show_stale_violations(offense_collection); end

  private

  sig { params(offenses: T::Array[T.nilable(::Packwerk::Offense)]).returns(::String) }
  def offenses_list(offenses); end

  sig { params(offenses: T::Array[T.nilable(::Packwerk::Offense)]).returns(::String) }
  def offenses_summary(offenses); end
end

class Packwerk::Formatters::ProgressFormatter
  sig { params(out: T.any(::IO, ::StringIO), style: ::Packwerk::OutputStyle).void }
  def initialize(out, style: T.unsafe(nil)); end

  def finished(execution_time); end
  def interrupted; end
  def mark_as_failed; end
  def mark_as_inspected; end
  def started(target_files); end
  def started_validation; end
end

module Packwerk::Generators
  extend ::ActiveSupport::Autoload
end

class Packwerk::Generators::ConfigurationFile
  sig { params(root: ::String, out: T.any(::IO, ::StringIO)).void }
  def initialize(root:, out: T.unsafe(nil)); end

  sig { returns(T::Boolean) }
  def generate; end

  private

  def render; end
  def template; end

  class << self
    def generate(root:, out:); end
  end
end

Packwerk::Generators::ConfigurationFile::CONFIGURATION_TEMPLATE_FILE_PATH = T.let(T.unsafe(nil), String)

class Packwerk::Generators::RootPackage
  def initialize(root:, out: T.unsafe(nil)); end

  sig { returns(T::Boolean) }
  def generate; end

  class << self
    def generate(root:, out:); end
  end
end

class Packwerk::Graph
  def initialize(*edges); end

  def acyclic?; end
  def cycles; end

  private

  def add_cycle(cycle); end
  def neighbours(node); end
  def nodes; end
  def process; end
  def visit(node, visited_nodes: T.unsafe(nil), path: T.unsafe(nil)); end
end

module Packwerk::Node
  class << self
    def class?(node); end
    def class_or_module_name(class_or_module_node); end
    def constant?(node); end
    def constant_assignment?(node); end
    def constant_name(constant_node); end
    def each_child(node); end
    def enclosing_namespace_path(starting_node, ancestors:); end
    def hash?(node); end
    def literal_value(string_or_symbol_node); end
    def location(node); end
    def method_arguments(method_call_node); end
    def method_call?(node); end
    def method_name(method_call_node); end
    def module_name_from_definition(node); end
    def name_location(node); end
    def parent_class(class_node); end

    sig { params(ancestors: T::Array[::AST::Node]).returns(::String) }
    def parent_module_name(ancestors:); end

    def string?(node); end
    def symbol?(node); end
    def value_from_hash(hash_node, key); end

    private

    def hash_pair_key(hash_pair_node); end
    def hash_pair_value(hash_pair_node); end
    def hash_pairs(hash_node); end
    def method_call_node(block_node); end
    def module_creation?(node); end
    def name_from_block_definition(node); end
    def name_part_from_definition(node); end
    def receiver(method_call_or_block_node); end
    def type_of(node); end
  end
end

class Packwerk::Node::Location < ::Struct
  def column; end
  def column=(_); end
  def line; end
  def line=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Packwerk::Node::TypeError < ::ArgumentError; end

class Packwerk::NodeProcessor
  sig { params(reference_extractor: ::Packwerk::ReferenceExtractor, absolute_file: ::String).void }
  def initialize(reference_extractor:, absolute_file:); end

  sig do
    params(
      node: ::Parser::AST::Node,
      ancestors: T::Array[::Parser::AST::Node]
    ).returns(T.nilable(::Packwerk::UnresolvedReference))
  end
  def call(node, ancestors); end
end

class Packwerk::NodeProcessorFactory < ::T::Struct
  const :constant_name_inspectors, T::Array[::Packwerk::ConstantNameInspector]
  const :context_provider, ::Packwerk::ConstantDiscovery
  const :root_path, ::String

  sig { params(absolute_file: ::String, node: ::AST::Node).returns(::Packwerk::NodeProcessor) }
  def for(absolute_file:, node:); end

  private

  sig { params(node: ::AST::Node).returns(::Packwerk::ReferenceExtractor) }
  def reference_extractor(node:); end

  class << self
    def inherited(s); end
  end
end

class Packwerk::NodeVisitor
  sig { params(node_processor: ::Packwerk::NodeProcessor).void }
  def initialize(node_processor:); end

  def visit(node, ancestors:, result:); end
end

class Packwerk::Offense
  sig { params(file: ::String, message: ::String, location: T.nilable(::Packwerk::Node::Location)).void }
  def initialize(file:, message:, location: T.unsafe(nil)); end

  sig { returns(::String) }
  def file; end

  sig { returns(T.nilable(::Packwerk::Node::Location)) }
  def location; end

  sig { returns(::String) }
  def message; end

  sig { params(style: ::Packwerk::OutputStyle).returns(::String) }
  def to_s(style = T.unsafe(nil)); end
end

class Packwerk::OffenseCollection
  sig do
    params(
      root_path: ::String,
      deprecated_references: T::Hash[::Packwerk::Package, ::Packwerk::DeprecatedReferences]
    ).void
  end
  def initialize(root_path, deprecated_references = T.unsafe(nil)); end

  sig { params(offense: ::Packwerk::Offense).void }
  def add_offense(offense); end

  sig { void }
  def dump_deprecated_references_files; end

  sig { returns(T::Array[::Packwerk::Offense]) }
  def errors; end

  sig { params(offense: ::Packwerk::Offense).returns(T::Boolean) }
  def listed?(offense); end

  sig { returns(T::Array[::Packwerk::ReferenceOffense]) }
  def new_violations; end

  sig { returns(T::Array[::Packwerk::Offense]) }
  def outstanding_offenses; end

  sig { returns(T::Boolean) }
  def stale_violations?; end

  private

  sig { params(package: ::Packwerk::Package).returns(::String) }
  def deprecated_references_file_for(package); end

  sig { params(package: ::Packwerk::Package).returns(::Packwerk::DeprecatedReferences) }
  def deprecated_references_for(package); end
end

module Packwerk::OffensesFormatter
  interface!

  sig { abstract.params(offenses: T::Array[T.nilable(::Packwerk::Offense)]).returns(::String) }
  def show_offenses(offenses); end

  sig { abstract.params(offense_collection: ::Packwerk::OffenseCollection).returns(::String) }
  def show_stale_violations(offense_collection); end
end

module Packwerk::OutputStyle
  interface!

  sig { abstract.returns(::String) }
  def error; end

  sig { abstract.returns(::String) }
  def filename; end

  sig { abstract.returns(::String) }
  def reset; end
end

module Packwerk::OutputStyles
  extend ::ActiveSupport::Autoload
end

class Packwerk::OutputStyles::Coloured
  include ::Packwerk::OutputStyle

  sig { override.returns(::String) }
  def error; end

  sig { override.returns(::String) }
  def filename; end

  sig { override.returns(::String) }
  def reset; end
end

class Packwerk::OutputStyles::Plain
  include ::Packwerk::OutputStyle

  sig { override.returns(::String) }
  def error; end

  sig { override.returns(::String) }
  def filename; end

  sig { override.returns(::String) }
  def reset; end
end

class Packwerk::Package
  include ::Comparable

  sig { params(name: ::String, config: T.nilable(T.any(::FalseClass, T::Hash[T.untyped, T.untyped]))).void }
  def initialize(name:, config:); end

  sig { params(other: T.untyped).returns(T.nilable(::Integer)) }
  def <=>(other); end

  sig { returns(T::Array[::String]) }
  def dependencies; end

  sig { params(package: ::Packwerk::Package).returns(T::Boolean) }
  def dependency?(package); end

  sig { returns(T::Boolean) }
  def enforce_dependencies?; end

  sig { returns(T.nilable(T.any(T::Array[::String], T::Boolean))) }
  def enforce_privacy; end

  sig { params(other: T.untyped).returns(T::Boolean) }
  def eql?(other); end

  sig { returns(::Integer) }
  def hash; end

  sig { returns(::String) }
  def name; end

  sig { params(path: ::String).returns(T::Boolean) }
  def package_path?(path); end

  sig { returns(::String) }
  def public_path; end

  sig { params(path: ::String).returns(T::Boolean) }
  def public_path?(path); end

  sig { returns(T::Boolean) }
  def root?; end

  sig { returns(::String) }
  def to_s; end

  sig { returns(T.nilable(::String)) }
  def user_defined_public_path; end
end

Packwerk::Package::ROOT_PACKAGE_NAME = T.let(T.unsafe(nil), String)

class Packwerk::PackageSet
  extend T::Generic
  include ::Enumerable

  Elem = type_member(fixed: Packwerk::Package)

  sig { params(packages: T::Array[::Packwerk::Package]).void }
  def initialize(packages); end

  sig { override.params(blk: T.proc.params(arg0: ::Packwerk::Package).returns(T.untyped)).returns(T.untyped) }
  def each(&blk); end

  sig { params(name: ::String).returns(T.nilable(::Packwerk::Package)) }
  def fetch(name); end

  sig { params(file_path: T.any(::Pathname, ::String)).returns(::Packwerk::Package) }
  def package_from_path(file_path); end

  sig { returns(T::Hash[::String, ::Packwerk::Package]) }
  def packages; end

  class << self
    sig do
      params(
        root_path: ::String,
        package_pathspec: T.nilable(T.any(::String, T::Array[::String]))
      ).returns(Packwerk::PackageSet)
    end
    def load_all_from(root_path, package_pathspec: T.unsafe(nil)); end

    sig do
      params(
        root_path: ::String,
        package_pathspec: T.any(::String, T::Array[::String]),
        exclude_pathspec: T.nilable(T.any(::String, T::Array[::String]))
      ).returns(T::Array[::Pathname])
    end
    def package_paths(root_path, package_pathspec, exclude_pathspec = T.unsafe(nil)); end

    private

    sig { params(packages: T::Array[::Packwerk::Package]).void }
    def create_root_package_if_none_in(packages); end

    sig { params(globs: T::Array[::String], path: ::Pathname).returns(T::Boolean) }
    def exclude_path?(globs, path); end
  end
end

Packwerk::PackageSet::PACKAGE_CONFIG_FILENAME = T.let(T.unsafe(nil), String)

class Packwerk::ParseRun
  sig do
    params(
      absolute_files: T::Array[::String],
      configuration: ::Packwerk::Configuration,
      progress_formatter: ::Packwerk::Formatters::ProgressFormatter,
      offenses_formatter: ::Packwerk::OffensesFormatter
    ).void
  end
  def initialize(absolute_files:, configuration:, progress_formatter: T.unsafe(nil), offenses_formatter: T.unsafe(nil)); end

  sig { returns(::Packwerk::Result) }
  def check; end

  sig { returns(::Packwerk::Result) }
  def detect_stale_violations; end

  sig { returns(::Packwerk::Result) }
  def update_deprecations; end

  private

  sig { params(show_errors: T::Boolean).returns(::Packwerk::OffenseCollection) }
  def find_offenses(show_errors: T.unsafe(nil)); end

  sig do
    params(
      block: T.proc.params(path: ::String).returns(T::Array[::Packwerk::Offense])
    ).returns(T::Array[::Packwerk::Offense])
  end
  def serial_find_offenses(&block); end

  sig { params(failed: T::Boolean).void }
  def update_progress(failed: T.unsafe(nil)); end
end

Packwerk::ParseRun::ProcessFileProc = T.type_alias { T.proc.params(path: ::String).returns(T::Array[::Packwerk::Offense]) }

class Packwerk::ParsedConstantDefinitions
  def initialize(root_node:); end

  def local_reference?(constant_name, location: T.unsafe(nil), namespace_path: T.unsafe(nil)); end

  private

  def add_definition(constant_name, current_namespace_path, location); end
  def collect_local_definitions_from_root(node, current_namespace_path = T.unsafe(nil)); end

  class << self
    def reference_qualifications(constant_name, namespace_path:); end
  end
end

module Packwerk::Parsers; end

class Packwerk::Parsers::Erb
  include ::Packwerk::Parsers::ParserInterface

  def initialize(parser_class: T.unsafe(nil), ruby_parser: T.unsafe(nil)); end

  def call(io:, file_path: T.unsafe(nil)); end
  def parse_buffer(buffer, file_path:); end

  private

  def code_nodes(node); end
  def to_ruby_ast(erb_ast, file_path); end
end

class Packwerk::Parsers::Factory
  include ::Singleton
  extend ::Singleton::SingletonClassMethods

  def erb_parser_class; end
  def erb_parser_class=(klass); end

  sig { params(path: ::String).returns(T.nilable(::Packwerk::Parsers::ParserInterface)) }
  def for_path(path); end
end

Packwerk::Parsers::Factory::ERB_REGEX = T.let(T.unsafe(nil), Regexp)
Packwerk::Parsers::Factory::RUBY_REGEX = T.let(T.unsafe(nil), Regexp)

class Packwerk::Parsers::ParseError < ::StandardError
  def initialize(result); end

  def result; end
end

class Packwerk::Parsers::ParseResult < ::Packwerk::Offense; end

module Packwerk::Parsers::ParserInterface
  interface!

  sig { abstract.params(io: ::File, file_path: ::String).returns(T.untyped) }
  def call(io:, file_path:); end
end

class Packwerk::Parsers::Ruby
  include ::Packwerk::Parsers::ParserInterface

  def initialize(parser_class: T.unsafe(nil)); end

  def call(io:, file_path: T.unsafe(nil)); end
end

class Packwerk::Parsers::Ruby::RaiseExceptionsParser < ::Parser::Ruby27
  def initialize(builder); end
end

class Packwerk::Parsers::Ruby::TolerateInvalidUtf8Builder < ::Parser::Builders::Default
  def string_value(token); end
end

Packwerk::PathSpec = T.type_alias { T.any(::String, T::Array[::String]) }

class Packwerk::Reference < ::Struct
  def constant; end
  def constant=(_); end
  def relative_path; end
  def relative_path=(_); end
  def source_location; end
  def source_location=(_); end
  def source_package; end
  def source_package=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

module Packwerk::ReferenceChecking
  extend ::ActiveSupport::Autoload
end

module Packwerk::ReferenceChecking::Checkers
  extend ::ActiveSupport::Autoload
end

module Packwerk::ReferenceChecking::Checkers::Checker
  interface!

  sig { abstract.params(reference: ::Packwerk::Reference).returns(T::Boolean) }
  def invalid_reference?(reference); end

  sig { abstract.returns(::Packwerk::ViolationType) }
  def violation_type; end
end

class Packwerk::ReferenceChecking::Checkers::DependencyChecker
  include ::Packwerk::ReferenceChecking::Checkers::Checker

  sig { override.params(reference: ::Packwerk::Reference).returns(T::Boolean) }
  def invalid_reference?(reference); end

  sig { override.returns(::Packwerk::ViolationType) }
  def violation_type; end
end

class Packwerk::ReferenceChecking::Checkers::PrivacyChecker
  include ::Packwerk::ReferenceChecking::Checkers::Checker

  sig { override.params(reference: ::Packwerk::Reference).returns(T::Boolean) }
  def invalid_reference?(reference); end

  sig { override.returns(::Packwerk::ViolationType) }
  def violation_type; end

  private

  sig { params(privacy_option: T.nilable(T.any(T::Array[::String], T::Boolean))).returns(T::Boolean) }
  def enforcement_disabled?(privacy_option); end

  sig do
    params(
      constant: ::Packwerk::ConstantDiscovery::ConstantContext,
      explicitly_private_constants: T::Array[::String]
    ).returns(T::Boolean)
  end
  def explicitly_private_constant?(constant, explicitly_private_constants:); end
end

class Packwerk::ReferenceChecking::ReferenceChecker
  sig { params(checkers: T::Array[::Packwerk::ReferenceChecking::Checkers::Checker]).void }
  def initialize(checkers); end

  sig { params(reference: T.any(::Packwerk::Offense, ::Packwerk::Reference)).returns(T::Array[::Packwerk::Offense]) }
  def call(reference); end
end

class Packwerk::ReferenceExtractor
  sig do
    params(
      constant_name_inspectors: T::Array[::Packwerk::ConstantNameInspector],
      root_node: ::AST::Node,
      root_path: ::String
    ).void
  end
  def initialize(constant_name_inspectors:, root_node:, root_path:); end

  sig do
    params(
      node: ::Parser::AST::Node,
      ancestors: T::Array[::Parser::AST::Node],
      absolute_file: ::String
    ).returns(T.nilable(::Packwerk::UnresolvedReference))
  end
  def reference_from_node(node, ancestors:, absolute_file:); end

  private

  def local_reference?(constant_name, name_location, namespace_path); end

  sig do
    params(
      constant_name: ::String,
      node: ::Parser::AST::Node,
      ancestors: T::Array[::Parser::AST::Node],
      absolute_file: ::String
    ).returns(T.nilable(::Packwerk::UnresolvedReference))
  end
  def reference_from_constant(constant_name, node:, ancestors:, absolute_file:); end

  class << self
    sig do
      params(
        unresolved_references_and_offenses: T::Array[T.any(::Packwerk::Offense, ::Packwerk::UnresolvedReference)],
        context_provider: ::Packwerk::ConstantDiscovery
      ).returns(T::Array[T.any(::Packwerk::Offense, ::Packwerk::Reference)])
    end
    def get_fully_qualified_references_and_offenses_from(unresolved_references_and_offenses, context_provider); end
  end
end

class Packwerk::ReferenceOffense < ::Packwerk::Offense
  sig do
    params(
      reference: ::Packwerk::Reference,
      violation_type: ::Packwerk::ViolationType,
      location: T.nilable(::Packwerk::Node::Location)
    ).void
  end
  def initialize(reference:, violation_type:, location: T.unsafe(nil)); end

  sig { returns(::Packwerk::Reference) }
  def reference; end

  sig { returns(::Packwerk::ViolationType) }
  def violation_type; end

  private

  sig { params(reference: ::Packwerk::Reference, violation_type: ::Packwerk::ViolationType).returns(::String) }
  def build_message(reference, violation_type); end
end

class Packwerk::Result < ::T::Struct
  const :message, ::String
  const :status, T::Boolean

  class << self
    def inherited(s); end
  end
end

class Packwerk::RunContext
  sig do
    params(
      root_path: ::String,
      load_paths: T::Array[::String],
      inflector: T.class_of(ActiveSupport::Inflector),
      cache_directory: ::Pathname,
      config_path: T.nilable(::String),
      package_paths: T.nilable(T.any(::String, T::Array[::String])),
      custom_associations: T.any(T::Array[::Symbol], T::Set[::Symbol]),
      checkers: T::Array[::Packwerk::ReferenceChecking::Checkers::Checker],
      cache_enabled: T::Boolean
    ).void
  end
  def initialize(root_path:, load_paths:, inflector:, cache_directory:, config_path: T.unsafe(nil), package_paths: T.unsafe(nil), custom_associations: T.unsafe(nil), checkers: T.unsafe(nil), cache_enabled: T.unsafe(nil)); end

  sig { params(absolute_file: ::String).returns(T::Array[::Packwerk::Offense]) }
  def process_file(absolute_file:); end

  private

  sig { returns(T::Array[::Packwerk::ConstantNameInspector]) }
  def constant_name_inspectors; end

  sig { returns(::Packwerk::ConstantDiscovery) }
  def context_provider; end

  sig { returns(::Packwerk::FileProcessor) }
  def file_processor; end

  sig { returns(::Packwerk::NodeProcessorFactory) }
  def node_processor_factory; end

  sig { returns(Packwerk::PackageSet) }
  def package_set; end

  sig { returns(::ConstantResolver) }
  def resolver; end

  class << self
    sig { params(configuration: ::Packwerk::Configuration).returns(::Packwerk::RunContext) }
    def from_configuration(configuration); end
  end
end

Packwerk::RunContext::DEFAULT_CHECKERS = T.let(T.unsafe(nil), Array)

class Packwerk::UnresolvedReference < ::Struct
  def constant_name; end
  def constant_name=(_); end
  def namespace_path; end
  def namespace_path=(_); end
  def relative_path; end
  def relative_path=(_); end
  def source_location; end
  def source_location=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

Packwerk::VERSION = T.let(T.unsafe(nil), String)

class Packwerk::ViolationType < ::T::Enum
  enums do
    Privacy = new
    Dependency = new
  end
end
