# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ComplianceManagement::Violations::ApprovedByCommitter do
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, state: :merged) }

  subject(:violation) { described_class.new(merge_request) }

  describe '#execute' do
    before do
      allow(merge_request).to receive(:committers).and_return([user, user2])
    end

    subject(:execute) { violation.execute }

    context 'when merge request is approved by someone who did not add a commit' do
      it 'does not create a ComplianceViolation' do
        expect { execute }.not_to change(MergeRequests::ComplianceViolation, :count)
      end
    end

    context 'when merge request is approved by someone who also added a commit' do
      before do
        merge_request.approver_users << user
        merge_request.approver_users << user2
        merge_request.approver_users << user3
      end

      it 'creates a ComplianceViolation for each violation', :aggregate_failures do
        expect { execute }.to change { merge_request.compliance_violations.count }.by(2)

        violations = merge_request.compliance_violations.where(reason: described_class::REASON)

        expect(violations.map(&:violating_user)).to contain_exactly(user, user2)
      end

      context 'when called more than once with the same violations' do
        before do
          create(:compliance_violation, :approved_by_committer, merge_request: merge_request, violating_user: user)
          create(:compliance_violation, :approved_by_committer, merge_request: merge_request, violating_user: user2)

          allow(merge_request).to receive(:committers).and_return([user, user3])
        end

        it 'does not insert duplicates', :aggregate_failures do
          expect { execute }.to change { merge_request.compliance_violations.count }.by(1)

          violations = merge_request.compliance_violations.where(reason: described_class::REASON)

          expect(violations.map(&:violating_user)).to contain_exactly(user, user2, user3)
        end
      end
    end
  end
end
