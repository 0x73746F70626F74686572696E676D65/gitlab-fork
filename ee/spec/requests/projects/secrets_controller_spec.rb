# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::SecretsController, type: :request, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  shared_examples 'renders the project secrets index template' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('projects/secrets/index')
    end
  end

  shared_examples 'returns a "not found" response' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /:namespace/:project/-/secrets' do
    subject(:request) { get project_secrets_url(project), params: { project_id: project.to_param } }

    before_all do
      project.add_owner(user)
    end

    before do
      sign_in(user)
    end

    context 'when feature flag "ci_tanukey_ui" is enabled' do
      before do
        stub_feature_flags(ci_tanukey_ui: project)
      end

      it_behaves_like 'renders the project secrets index template'
    end

    context 'when feature flag "ci_tanukey_ui" is disabled' do
      before do
        stub_feature_flags(ci_tanukey_ui: false)
      end

      it_behaves_like 'returns a "not found" response'
    end
  end
end
