# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService, feature_category: :seat_cost_management do
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:status) { :approved }
  let_it_be(:service) { described_class.new(current_user, user, status) }
  let_it_be(:is_admin) { true }
  let_it_be(:promotion_management_feature) { true }
  let!(:member_approval_for_group) { create(:member_approval, :for_group_member, user: user) }

  describe '#execute' do
    before do
      allow(current_user).to receive(:can_admin_all_resources?).and_return(is_admin) if current_user
      allow(service).to receive(:promotion_management_applicable?).and_return(promotion_management_feature)
    end

    context 'when service is not allowed to execute' do
      context 'when current_user is not present' do
        let(:current_user) { nil }

        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'when promotion_management_applicable? returns false' do
        let(:promotion_management_feature) { false }

        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'when current_user is not admin' do
        let(:is_admin) { false }

        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Unauthorized')
        end
      end
    end

    context 'when current_user is admin' do
      context 'when there are pending member approvals' do
        let!(:member_approval_for_another_project) do
          create(:member_approval, :for_project_member, user: user)
        end

        it 'updates the status of all pending member approvals' do
          service.execute

          expect(member_approval_for_group.reload.status).to eq('approved')
          expect(member_approval_for_another_project.reload.status).to eq('approved')
        end

        it 'returns a success response' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: user, status: status })
        end
      end

      context 'when there are no pending member approvals' do
        let(:member_approval_for_group) { nil }

        it 'returns a success response' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: user, status: status })
        end
      end

      context 'when updating member approvals fails' do
        before do
          allow(::Members::MemberApproval).to receive(:pending_member_approvals_for_user)
                                                .and_return([member_approval_for_group])
          allow(member_approval_for_group).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('FAILED_TO_APPLY_PROMOTIONS')
        end
      end
    end
  end
end
