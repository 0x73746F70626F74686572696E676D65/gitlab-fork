# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::Legacy, feature_category: :global_search do
  let_it_be(:merge_request) { create(:merge_request) }
  let(:serialized_record) do
    "MergeRequest #{merge_request.id} merge_request_#{merge_request.id} project_#{merge_request.project.id}"
  end

  it 'inherits from Reference' do
    expect(described_class.ancestors).to include(Search::Elastic::Reference)
  end

  describe '#serialize' do
    it 'returns the serialized record from DocumentReference' do
      expect(Gitlab::Elastic::DocumentReference).to receive(:serialize_record).with(merge_request).and_call_original

      expect(described_class.serialize(merge_request)).to eq(serialized_record)
    end
  end

  describe '#instantiate' do
    it 'returns an instance of DocumentReference' do
      expect(Gitlab::Elastic::DocumentReference).to receive(:deserialize).with(serialized_record).and_call_original

      deserialized_ref = described_class.instantiate(serialized_record)

      expect(deserialized_ref).to be_a(Gitlab::Elastic::DocumentReference)
      expect(deserialized_ref.identifier).to eq("merge_request_#{merge_request.id}")
      expect(deserialized_ref.operation).to eq(:index)
      expect(deserialized_ref.routing).to eq("project_#{merge_request.project.id}")
      expect(deserialized_ref.index_name).to eq('gitlab-test-merge_requests')
      expect(deserialized_ref.as_indexed_json).to include('id' => merge_request.id)
      expect(deserialized_ref.database_record).to eq(merge_request)
      expect(deserialized_ref.database_id).to eq(merge_request.id.to_s)
    end
  end
end
