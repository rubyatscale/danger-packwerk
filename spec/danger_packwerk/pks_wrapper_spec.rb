require 'spec_helper'
require 'English'

module DangerPackwerk
  RSpec.describe PksWrapper do
    let(:plugin) { dangerfile.packwerk }

    let(:valid_json_output) do
      {
        'offenses' => [
          {
            'violation_type' => 'privacy',
            'file' => 'packs/my_pack/app/models/user.rb',
            'line' => 42,
            'column' => 10,
            'constant_name' => '::OtherPack::PrivateClass',
            'referencing_pack_name' => 'packs/my_pack',
            'defining_pack_name' => 'packs/other_pack',
            'strict' => false,
            'message' => 'Privacy violation'
          }
        ]
      }.to_json
    end

    let(:empty_json_output) do
      { 'offenses' => [] }.to_json
    end

    # Use real Process::Status from a successful command for Sorbet compatibility
    let(:success_status) do
      `true`
      $CHILD_STATUS
    end
    let(:failure_status) do
      `false`
      $CHILD_STATUS
    end

    describe '.get_offenses_for_files' do
      it 'returns empty array when files is empty' do
        expect(described_class.get_offenses_for_files([])).to eq([])
      end

      it 'calls pks check with JSON output format' do
        allow(described_class).to receive(:run_pks_check)
          .with(['file1.rb', 'file2.rb'])
          .and_return([valid_json_output, '', success_status])

        described_class.get_offenses_for_files(['file1.rb', 'file2.rb'])

        expect(described_class).to have_received(:run_pks_check).with(['file1.rb', 'file2.rb'])
      end

      it 'returns PksOffense objects from JSON output' do
        allow(described_class).to receive(:run_pks_check)
          .and_return([valid_json_output, '', success_status])

        offenses = described_class.get_offenses_for_files(['file1.rb'])

        expect(offenses.length).to eq(1)
        expect(offenses.first).to be_a(PksOffense)
        expect(offenses.first.violation_type).to eq('privacy')
        expect(offenses.first.file).to eq('packs/my_pack/app/models/user.rb')
      end

      it 'returns empty array when no violations found' do
        allow(described_class).to receive(:run_pks_check)
          .and_return([empty_json_output, '', success_status])

        offenses = described_class.get_offenses_for_files(['file1.rb'])

        expect(offenses).to eq([])
      end

      it 'raises PksBinaryNotFoundError when pks command not found' do
        allow(described_class).to receive(:run_pks_check)
          .and_return(['', 'command not found: pks', failure_status])

        expect do
          described_class.get_offenses_for_files(['file1.rb'])
        end.to raise_error(PksWrapper::PksBinaryNotFoundError, /pks binary not found/)
      end

      it 'raises PksBinaryNotFoundError for No such file error' do
        allow(described_class).to receive(:run_pks_check)
          .and_return(['', 'No such file or directory', failure_status])

        expect do
          described_class.get_offenses_for_files(['file1.rb'])
        end.to raise_error(PksWrapper::PksBinaryNotFoundError, /pks binary not found/)
      end
    end

    describe '.run_pks_check' do
      it 'executes pks command with proper escaping' do
        allow(Open3).to receive(:capture3)
          .with('pks check --output-format json file1.rb file2.rb')
          .and_return([empty_json_output, '', success_status])

        described_class.run_pks_check(['file1.rb', 'file2.rb'])

        expect(Open3).to have_received(:capture3)
          .with('pks check --output-format json file1.rb file2.rb')
      end

      it 'escapes file paths with special characters' do
        allow(Open3).to receive(:capture3).and_return([empty_json_output, '', success_status])

        described_class.run_pks_check(['file with spaces.rb'])

        expect(Open3).to have_received(:capture3)
          .with('pks check --output-format json file\\ with\\ spaces.rb')
      end
    end

    describe '.pks_available?' do
      it 'returns true when pks is in PATH' do
        allow(Open3).to receive(:capture3)
          .with('which', 'pks')
          .and_return(['/usr/local/bin/pks', '', success_status])

        expect(described_class.pks_available?).to eq(true)
      end

      it 'returns false when pks is not in PATH' do
        allow(Open3).to receive(:capture3)
          .with('which', 'pks')
          .and_return(['', '', failure_status])

        expect(described_class.pks_available?).to eq(false)
      end
    end
  end
end
