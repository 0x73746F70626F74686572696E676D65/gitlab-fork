# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240219161432_index_all_projects.rb')

RSpec.describe IndexAllProjects, :elastic, feature_category: :global_search do
  let(:version) { 20240219161432 }

  it_behaves_like 'migration reindexes all data' do
    let(:objects) { create_list(:project, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 50_000 }
  end

  describe '#space_required_bytes' do
    let(:helper) { ::Gitlab::Elastic::Helper.default }
    let(:migration) { described_class.new(version) }

    subject(:space_required_bytes) { migration.space_required_bytes }

    context 'when elasticsearch_limit_indexing? is set to false' do
      it { is_expected.to eq(0) }
    end

    context 'when elasticsearch_limit_indexing? is set to true' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
        allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      end

      it 'returns space required' do
        expect(Project).to receive(:count).and_return(100)
        expect(helper).to receive(:index_size_bytes)
          .with(index_name: described_class::DOCUMENT_TYPE.index_name).and_return(1000)
        expect(helper).to receive(:documents_count)
          .with(index_name: described_class::DOCUMENT_TYPE.index_name).and_return(10)

        expect(space_required_bytes).to eq(9000)
      end

      it 'returns 0 when no projects exist in index' do
        expect(Project).to receive(:count).and_return(100)
        expect(helper).to receive(:index_size_bytes)
          .with(index_name: described_class::DOCUMENT_TYPE.index_name).and_return(1000)
        expect(helper).to receive(:documents_count)
          .with(index_name: described_class::DOCUMENT_TYPE.index_name).and_return(0)

        expect(space_required_bytes).to eq(0)
      end
    end
  end
end
