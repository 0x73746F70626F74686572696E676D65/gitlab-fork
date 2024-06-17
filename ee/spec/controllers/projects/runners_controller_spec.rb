# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::RunnersController, :saas, feature_category: :fleet_visibility do
  let_it_be(:user) { create(:user, :identity_verification_eligible, :with_sign_ins) }
  let_it_be(:namespace) { create(:namespace) }

  let(:project) { create(:project, namespace: namespace, creator: user) }
  let(:runner) { create(:ci_runner, :project, projects: [project]) }

  let(:params) do
    {
      namespace_id: project.namespace,
      project_id: project,
      id: runner
    }
  end

  before do
    create(:gitlab_subscription, namespace: namespace, hosted_plan: create(:free_plan))

    sign_in(user)
    project.add_maintainer(user)
  end

  describe '#toggle_shared_runners' do
    let_it_be(:group) { create(:group) }

    let(:project) { create(:project, group: group) }

    shared_examples 'does not permit enabling shared runners' do
      it 'does not enable shared runners', :aggregate_failures do
        post :toggle_shared_runners, params: params

        project.reload

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(project.shared_runners_enabled).to eq(false)
        expect(json_response['error']).to eq(error_msg)
      end
    end

    context 'when shared runners are off' do
      before do
        project.update!(shared_runners_enabled: false)
      end

      context 'when user has valid credit card' do
        before do
          create(:credit_card_validation, user: user)
        end

        it 'permits enabling and disabling shared runners', :aggregate_failures do
          post :toggle_shared_runners, params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.shared_runners_enabled).to eq(true)

          post :toggle_shared_runners, params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.shared_runners_enabled).to eq(false)
        end
      end

      context 'when user does not have valid credit card' do
        it_behaves_like 'does not permit enabling shared runners' do
          let(:error_msg) { 'Shared runners enabled cannot be enabled until a valid credit card is on file' }
        end
      end

      context 'when user has not completed identity verification' do
        before do
          # credit card verification takes precedence over identity verification so we need to disable it
          stub_feature_flags(ci_require_credit_card_on_free_plan: false)
        end

        it_behaves_like 'does not permit enabling shared runners' do
          let(:error_msg) { 'Shared runners enabled cannot be enabled until identity verification is completed' }
        end
      end
    end
  end
end
