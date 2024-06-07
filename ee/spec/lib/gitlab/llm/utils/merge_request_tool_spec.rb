# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::MergeRequestTool, feature_category: :ai_abstraction_layer do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.owner }

  let(:source_project) { project }
  let(:target_project) { project }
  let(:source_branch) { 'feature' }
  let(:target_branch) { 'master' }

  let(:character_limit) { 1000 }

  let(:arguments) do
    {
      source_project: source_project,
      target_project: target_project,
      source_branch: source_branch,
      target_branch: target_branch,
      character_limit: character_limit
    }
  end

  context "when there is a diff with an edge case" do
    let(:good_diff) { { diff: "@@ -0,0 +1 @@hellothere\n+🌚\n" } }
    let(:compare) { instance_double(Compare) }

    before do
      allow(CompareService).to receive_message_chain(:new, :execute).and_return(compare)
    end

    context 'when a diff is not encoded with UTF-8' do
      let(:other_diff) do
        { diff: "@@ -1 +1 @@\n-This should not be in the prompt\n+#{(0..255).map(&:chr).join}\n" }
      end

      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff, other_diff]) }

      it 'does not raise any error and not contain the non-UTF diff' do
        allow(compare).to receive(:raw_diffs).and_return(diff_files)
        extracted_diff = described_class.extract_diff(**arguments)
        expect(extracted_diff).to include("hellothere")
        expect(extracted_diff).not_to include("This should not be in the prompt")
      end
    end

    context 'when a diff contains the binary notice' do
      let(:binary_message) { Gitlab::Git::Diff.binary_message('a', 'b') }
      let(:other_diff) { { diff: binary_message } }
      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff, other_diff]) }

      it 'does not contain the binary diff' do
        allow(compare).to receive(:raw_diffs).and_return(diff_files)
        extracted_diff = described_class.extract_diff(**arguments)

        expect(extracted_diff).to include("hellothere")
        expect(extracted_diff).not_to include(binary_message)
      end
    end

    context 'when extracted diff is blank' do
      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff]) }

      before do
        allow(CompareService).to receive_message_chain(:new, :execute).and_return(nil)
      end

      it 'returns nil' do
        extracted_diff = described_class.extract_diff(**arguments)
        expect(extracted_diff).to be_nil
      end
    end
  end
end
