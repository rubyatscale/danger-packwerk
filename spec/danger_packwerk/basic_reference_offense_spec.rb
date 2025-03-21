require 'spec_helper'

module DangerPackwerk
  RSpec.describe BasicReferenceOffense do
    let(:package_yml) { 'packs/some_pack/package.yml' }
    let(:package_todo_yml) { 'packs/some_pack/package_todo.yml' }
    let(:plugin) { dangerfile.packwerk }

    before do
      write_file(package_yml, <<~YML)
        enforce_privacy: true
        enforce_dependencies: true
      YML

      write_file(package_todo_yml, <<~YML)
        packs/other_pack:
          "::OtherPack::ClassName":
            violations:
            - dependency
            files:
            - packs/some_pack/file.rb
          ? "::OtherPack::ReallyLongClassNameThatCausesSerializerToUseExplicitMappingYamlSyntax"
          : violations:
            - dependency
            files:
            - packs/some_pack/file.rb
      YML
    end

    # If a class name is long, it can cause the YAML serializer generating
    # these files to use the explicit mapping syntax that breaks the key onto
    # multiple lines. It's valid YAML, but an edge case that can cause issues
    # for libraries like this one.
    # * https://github.com/prettier/prettier/issues/5599
    # * https://github.com/jeremyfa/yaml.js/issues/128
    it 'can parse yaml that contains explicit mapping syntax' do
      offenses = described_class.from(package_todo_yml)
      expect(offenses.count).to eq(2)
    end
  end
end
