# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:raw_diff) { "@@ -1,4 +1,4 @@\n # NEW\n \n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file." }

    let(:diff_file) do
      instance_double(
        Gitlab::Diff::File,
        raw_diff: raw_diff,
        new_path: 'NEW.md'
      )
    end

    let(:hunk) do
      {
        added: [
          instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 3, text: '+Welcome!'),
          instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 4, text: '+This is a new file.')
        ],
        removed: [
          instance_double(Gitlab::Diff::Line, old_pos: 3, new_pos: 3, text: '-Welcome'),
          instance_double(Gitlab::Diff::Line, old_pos: 4, new_pos: 3, text: '-This is a new file')
        ]
      }
    end

    subject(:prompt) { described_class.new(diff_file, hunk).to_prompt }

    it 'includes new_path' do
      expect(prompt).to include(diff_file.new_path)
    end

    it 'includes raw diff' do
      expect(prompt).to include(" # NEW\n \n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file.")
    end

    it 'does not include git diff prefix' do
      expect(prompt).not_to include('@@ -1,4 +1,4 @@')
    end

    it 'includes new and old hunks based on given hunk' do
      new_hunk = <<~HUNK
      3: Welcome!
      4: This is a new file.
      HUNK

      old_hunk = <<~HUNK
      3: Welcome
      4: This is a new file
      HUNK

      expect(prompt).to include(new_hunk)
      expect(prompt).to include(old_hunk)
    end

    context 'when raw diff is blank' do
      let(:raw_diff) { '' }

      it 'returns nil' do
        expect(prompt).to be_nil
      end
    end
  end
end
