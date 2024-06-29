# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update MemberApproval User Status', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:member_approval) { create(:member_approval, user: user) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  let(:mutation) { graphql_mutation(:process_user_billable_promotion_request, input) }
  let(:action) { 'APPROVED' }
  let(:promotion_feature) { true }
  let(:mutation_response) { graphql_mutation_response(:process_user_billable_promotion_request) }
  let(:input) do
    {
      user_id: user.to_global_id.to_s,
      status: action
    }
  end

  before do
    allow(License).to receive(:current).and_return(license)
    stub_feature_flags(member_promotion_management: promotion_feature)
    stub_application_setting(enable_member_promotion_management: true)
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when called by a non-admin' do
    let(:current_user) { create(:user) }

    it 'returns an error' do
      mutate

      expect(graphql_errors).to contain_exactly(
        hash_including(
          'message' => "The resource that you are attempting to access does not exist or you don't have " \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when promotion_management_applicable? returns false' do
    let(:promotion_feature) { false }

    it 'returns an error' do
      mutate

      expect(graphql_errors).to contain_exactly(
        hash_including(
          'message' => "The resource that you are attempting to access does not exist or you don't have " \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when pending request exists' do
    context 'when Approved' do
      it 'approves pending requests' do
        mutate

        expect(member_approval.reload.status).to eq("approved")
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['result']).to eq("SUCCESS")
      end
    end

    context 'when DENIED' do
      let(:action) { 'DENIED' }

      it 'denies pending requests' do
        mutate

        expect(member_approval.reload.status).to eq("denied")
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['result']).to eq("SUCCESS")
      end
    end

    context 'when an error is encountered' do
      before do
        allow(Members::MemberApproval).to receive(:pending_member_approvals_for_user).and_return([member_approval])
        allow(member_approval).to receive(:update!).and_raise(
          ActiveRecord::RecordInvalid)
      end

      it 'returns an error' do
        mutate

        expect(mutation_response["errors"]).to include("FAILED_TO_APPLY_PROMOTIONS")
        expect(mutation_response["result"]).to eq("FAILED")
      end
    end
  end
end
