# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Mergeability::CheckRequestedChangesService, feature_category: :code_review_workflow do
  subject(:service) { described_class.new(merge_request: merge_request, params: params) }

  let_it_be(:project) { build(:project) }
  let_it_be(:merge_request) { build(:merge_request, source_project: project, reviewers: [build(:user)]) }
  let(:params) { {} }

  let(:result) { service.execute }

  describe '#skip?' do
    it 'returns false' do
      expect(service.skip?).to eq false
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(service.cacheable?).to eq false
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(mr_reviewer_requests_changes: false)
    end

    it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS }
  end

  context 'when license is invalid' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: false)
    end

    it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS }
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    describe 'when no reviewer has requested changes' do
      it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS }
    end

    describe 'when a reviewer has requested changes' do
      before_all do
        merge_request.merge_request_reviewers.first.update!(state: :requested_changes)
      end

      it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS }
    end
  end
end
