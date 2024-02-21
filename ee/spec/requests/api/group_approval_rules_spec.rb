# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupApprovalRules, :aggregate_failures, feature_category: :source_code_management do
  let_it_be(:group) { create(:group_with_members) }
  let_it_be(:user_with_access) { create(:user) }
  let_it_be(:project) do
    create(:project, :public, :repository, creator: user_with_access, group: group,
      only_allow_merge_if_pipeline_succeeds: false)
  end

  before do
    stub_licensed_features(merge_request_approvers: true)
  end

  before_all do
    group.add_owner(user_with_access)
  end

  shared_examples_for 'check for approval_group_rule feature flag' do
    context 'when approval_group_rules flag is disabled' do
      before do
        stub_feature_flags(approval_group_rules: false)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples_for 'check that user can update approval rules' do
    context 'when the user does not have access' do
      let(:current_user) { create(:user) }

      it 'returns 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /groups/:id/approval_rules' do
    let(:schema) { 'public_api/v4/group_approval_rule' }
    let(:url) { "/groups/#{group.id}/approval_rules" }
    let(:current_user) { user_with_access }
    let(:name) { 'name' }
    let(:required_params) do
      {
        name: name,
        approvals_required: 10
      }
    end

    let(:params) { required_params }

    subject(:request) { post api(url, current_user, admin_mode: current_user.admin?), params: params }

    it_behaves_like 'check for approval_group_rule feature flag'
    it_behaves_like 'check that user can update approval rules'

    it 'returns 201 status' do
      request

      expect(response).to have_gitlab_http_status(:created)
      expect(response).to match_response_schema(schema, dir: 'ee')
    end

    context 'when the user is an admin' do
      let(:current_user) { create(:admin) }

      it 'returns 201 status' do
        request

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the user does not have access' do
      let(:current_user) { create(:user) }

      it 'returns 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when missing parameters' do
      let(:params) { {} }

      it 'returns 400 status' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'with an invalid parameter' do
      let(:name) { '' }

      it 'returns 400 status' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq({ "name" => ["can't be blank"] })
      end
    end

    context 'with user_id or group_id params' do
      context 'with user_ids' do
        let(:params) { required_params.merge(user_ids: [user_with_access.id]) }

        it 'returns a user' do
          request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['users'].size).to be 1
          expect(json_response.dig('users', 0, 'id')).to eq(user_with_access.id)
        end
      end

      context 'with group_ids' do
        let(:params) { required_params.merge(group_ids: [group.id]) }

        it 'returns a group' do
          request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['groups'].size).to be 1
          expect(json_response.dig('groups', 0, 'id')).to eq(group.id)
        end
      end
    end
  end

  describe 'PUT /groups/:id/approval_rules/:approval_rule_id' do
    let_it_be(:approval_group_rule) { create(:approval_group_rule, group: group) }
    let(:schema) { 'public_api/v4/group_approval_rule' }
    let(:url) { "/groups/#{group.id}/approval_rules/#{approval_group_rule.id}" }

    let(:current_user) { user_with_access }
    let(:name) { 'name' }
    let(:params) do
      {}
    end

    subject(:request) { put api(url, current_user), params: params }

    it_behaves_like 'check for approval_group_rule feature flag'
    it_behaves_like 'check that user can update approval rules'

    it 'returns 200 status' do
      request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema(schema, dir: 'ee')
    end

    context 'when the approval rule does not exist' do
      let(:url) { "/groups/#{group.id}/approval_rules/0" }

      it 'responds with not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with an invalid parameter' do
      let(:params) { { name: '' } }

      it 'returns 400 status' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq({ "name" => ["can't be blank"] })
      end
    end

    context 'when the approval rule is not found' do
      let(:url) { "/groups/#{group.id}/approval_rules/0" }

      it 'returns 404 status' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Approval Rule Not Found')
      end
    end

    context 'with user_id or group_id params' do
      context 'with user_ids' do
        let(:params) { { user_ids: [user_with_access.id] } }

        it 'returns a user' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['users'].size).to be 1
          expect(json_response.dig('users', 0, 'id')).to eq(user_with_access.id)
        end
      end

      context 'with group_ids' do
        let(:params) { { group_ids: [group.id] } }

        it 'returns a group' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['groups'].size).to be 1
          expect(json_response.dig('groups', 0, 'id')).to eq(group.id)
        end
      end
    end
  end
end
