# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::Mergeability::DetailedMergeStatusService, feature_category: :code_review_workflow do
  subject(:detailed_merge_status) { described_class.new(merge_request: merge_request).execute }

  let(:merge_request) { create(:merge_request) }

  context 'when the MR is unapproved but not temporarily unapproved' do
    before do
      create(:any_approver_rule, merge_request: merge_request, approvals_required: 2)
    end

    it 'returns approvals_syncing status' do
      expect(detailed_merge_status).to eq(:not_approved)
    end
  end

  context 'when the MR is temporarily unapproved' do
    before do
      merge_request.approval_state.temporarily_unapprove!
    end

    it 'returns approvals_syncing status' do
      expect(detailed_merge_status).to eq(:approvals_syncing)
    end
  end
end
