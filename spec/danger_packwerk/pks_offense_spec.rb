require 'spec_helper'

module DangerPackwerk
  RSpec.describe PksOffense do
    # PksOffense doesn't need Danger plugin context, but spec_helper includes it
    let(:plugin) { dangerfile.packwerk }
    let(:fixtures_path) { File.join(__dir__, '..', 'fixtures', 'pks_output') }
    let(:privacy_offense_hash) do
      {
        'violation_type' => 'privacy',
        'file' => 'packs/my_pack/app/models/user.rb',
        'line' => 42,
        'column' => 10,
        'constant_name' => '::OtherPack::PrivateClass',
        'referencing_pack_name' => 'packs/my_pack',
        'defining_pack_name' => 'packs/other_pack',
        'strict' => false,
        'message' => 'Privacy violation: ::OtherPack::PrivateClass is private'
      }
    end

    let(:dependency_offense_hash) do
      {
        'violation_type' => 'dependency',
        'file' => 'packs/my_pack/app/services/user_service.rb',
        'line' => 15,
        'column' => 5,
        'constant_name' => '::ThirdPack::SomeConstant',
        'referencing_pack_name' => 'packs/my_pack',
        'defining_pack_name' => 'packs/third_pack',
        'strict' => true,
        'message' => 'Dependency violation: packs/my_pack does not declare packs/third_pack as a dependency'
      }
    end

    describe '.from_hash' do
      it 'creates a PksOffense from a hash' do
        offense = described_class.from_hash(privacy_offense_hash)

        expect(offense.violation_type).to eq('privacy')
        expect(offense.file).to eq('packs/my_pack/app/models/user.rb')
        expect(offense.line).to eq(42)
        expect(offense.column).to eq(10)
        expect(offense.constant_name).to eq('::OtherPack::PrivateClass')
        expect(offense.referencing_pack_name).to eq('packs/my_pack')
        expect(offense.defining_pack_name).to eq('packs/other_pack')
        expect(offense.strict).to eq(false)
        expect(offense.message).to eq('Privacy violation: ::OtherPack::PrivateClass is private')
      end

      it 'defaults strict to false when not provided' do
        hash = privacy_offense_hash.except('strict')
        offense = described_class.from_hash(hash)
        expect(offense.strict).to eq(false)
      end

      it 'defaults message to empty string when not provided' do
        hash = privacy_offense_hash.except('message')
        offense = described_class.from_hash(hash)
        expect(offense.message).to eq('')
      end
    end

    describe '.from_json' do
      it 'parses JSON string with offenses array' do
        json = {
          'offenses' => [privacy_offense_hash, dependency_offense_hash]
        }.to_json

        offenses = described_class.from_json(json)

        expect(offenses.length).to eq(2)
        expect(offenses[0].violation_type).to eq('privacy')
        expect(offenses[1].violation_type).to eq('dependency')
      end

      it 'returns empty array when no offenses key' do
        json = {}.to_json
        offenses = described_class.from_json(json)
        expect(offenses).to eq([])
      end

      it 'returns empty array when offenses is empty' do
        json = { 'offenses' => [] }.to_json
        offenses = described_class.from_json(json)
        expect(offenses).to eq([])
      end
    end

    describe 'BasicReferenceOffense interface compatibility' do
      let(:offense) { described_class.from_hash(privacy_offense_hash) }

      it 'provides class_name alias for constant_name' do
        expect(offense.class_name).to eq(offense.constant_name)
      end

      it 'provides type alias for violation_type' do
        expect(offense.type).to eq(offense.violation_type)
      end

      it 'provides to_package_name alias for defining_pack_name' do
        expect(offense.to_package_name).to eq(offense.defining_pack_name)
      end

      it 'provides from_package_name alias for referencing_pack_name' do
        expect(offense.from_package_name).to eq(offense.referencing_pack_name)
      end
    end

    describe '#privacy?' do
      it 'returns true for privacy violations' do
        offense = described_class.from_hash(privacy_offense_hash)
        expect(offense.privacy?).to eq(true)
        expect(offense.dependency?).to eq(false)
      end
    end

    describe '#dependency?' do
      it 'returns true for dependency violations' do
        offense = described_class.from_hash(dependency_offense_hash)
        expect(offense.dependency?).to eq(true)
        expect(offense.privacy?).to eq(false)
      end
    end

    describe 'equality' do
      let(:offense1) { described_class.from_hash(privacy_offense_hash) }
      let(:offense2) { described_class.from_hash(privacy_offense_hash) }
      let(:different_offense) { described_class.from_hash(dependency_offense_hash) }

      it 'considers offenses equal when key fields match' do
        expect(offense1).to eq(offense2)
        expect(offense1.eql?(offense2)).to eq(true)
      end

      it 'considers offenses different when key fields differ' do
        expect(offense1).not_to eq(different_offense)
        expect(offense1.eql?(different_offense)).to eq(false)
      end

      it 'produces consistent hash values for equal offenses' do
        expect(offense1.hash).to eq(offense2.hash)
      end

      it 'can be used in a Set' do
        set = Set.new([offense1, offense2, different_offense])
        expect(set.length).to eq(2)
      end

      it 'can be used as hash keys' do
        hash = { offense1 => 'first', offense2 => 'second' }
        expect(hash.length).to eq(1)
        expect(hash[offense1]).to eq('second')
      end
    end

    describe 'fixture-based tests' do
      describe 'no_violations.json' do
        let(:json) { File.read(File.join(fixtures_path, 'no_violations.json')) }

        it 'parses empty offenses array' do
          offenses = described_class.from_json(json)
          expect(offenses).to eq([])
        end
      end

      describe 'privacy_violation.json' do
        let(:json) { File.read(File.join(fixtures_path, 'privacy_violation.json')) }

        it 'parses a single privacy violation' do
          offenses = described_class.from_json(json)

          expect(offenses.length).to eq(1)
          offense = offenses.first
          expect(offense.violation_type).to eq('privacy')
          expect(offense.file).to eq('packs/my_pack/app/models/user.rb')
          expect(offense.line).to eq(42)
          expect(offense.column).to eq(10)
          expect(offense.constant_name).to eq('::OtherPack::PrivateClass')
          expect(offense.referencing_pack_name).to eq('packs/my_pack')
          expect(offense.defining_pack_name).to eq('packs/other_pack')
          expect(offense.strict).to eq(false)
          expect(offense.privacy?).to eq(true)
          expect(offense.dependency?).to eq(false)
        end
      end

      describe 'dependency_violation.json' do
        let(:json) { File.read(File.join(fixtures_path, 'dependency_violation.json')) }

        it 'parses a single dependency violation with strict mode' do
          offenses = described_class.from_json(json)

          expect(offenses.length).to eq(1)
          offense = offenses.first
          expect(offense.violation_type).to eq('dependency')
          expect(offense.file).to eq('packs/my_pack/app/services/user_service.rb')
          expect(offense.line).to eq(15)
          expect(offense.column).to eq(5)
          expect(offense.constant_name).to eq('::ThirdPack::SomeConstant')
          expect(offense.referencing_pack_name).to eq('packs/my_pack')
          expect(offense.defining_pack_name).to eq('packs/third_pack')
          expect(offense.strict).to eq(true)
          expect(offense.privacy?).to eq(false)
          expect(offense.dependency?).to eq(true)
        end
      end

      describe 'multiple_violations.json' do
        let(:json) { File.read(File.join(fixtures_path, 'multiple_violations.json')) }

        it 'parses multiple violations of different types' do
          offenses = described_class.from_json(json)

          expect(offenses.length).to eq(3)

          privacy_offenses = offenses.select(&:privacy?)
          dependency_offenses = offenses.select(&:dependency?)

          expect(privacy_offenses.length).to eq(2)
          expect(dependency_offenses.length).to eq(1)
        end

        it 'preserves all offense details' do
          offenses = described_class.from_json(json)

          files = offenses.map(&:file)
          expect(files).to contain_exactly(
            'packs/my_pack/app/models/user.rb',
            'packs/my_pack/app/services/user_service.rb',
            'packs/another_pack/app/models/order.rb'
          )
        end
      end

      describe 'strict_mode_violation.json' do
        let(:json) { File.read(File.join(fixtures_path, 'strict_mode_violation.json')) }

        it 'parses strict mode privacy violation' do
          offenses = described_class.from_json(json)

          expect(offenses.length).to eq(1)
          offense = offenses.first
          expect(offense.strict).to eq(true)
          expect(offense.privacy?).to eq(true)
        end
      end
    end
  end
end
