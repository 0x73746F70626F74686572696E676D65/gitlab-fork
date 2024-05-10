# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::LearnGitlabController, :saas, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  describe 'GET #show' do
    let(:params) { { namespace_id: namespace.to_param, project_id: project } }

    subject(:action) { get :show, params: params }

    before_all do
      namespace.add_owner(user)
    end

    context 'for unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'for authenticated user' do
      before do
        sign_in(user)
      end

      context 'when learn gitlab is available' do
        before do
          create(:onboarding_progress, namespace: namespace)
        end

        it { is_expected.to render_template(:show) }

        context 'when not on gitlab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when learn_gitlab is not available' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
