RSpec.shared_context 'danger plugin' do
  let(:dangerfile) { testing_dangerfile }
  let(:modified_files) { [] }
  let(:added_files) { [] }
  let(:deleted_files) { [] }
  let(:renamed_files) { [] }

  before do
    allow(plugin.git).to receive(:modified_files).and_return(modified_files)
    allow(plugin.git).to receive(:added_files).and_return(added_files)
    allow(plugin.git).to receive(:deleted_files).and_return(deleted_files)
    allow(plugin.git).to receive(:renamed_files).and_return(renamed_files)
  end
end
