# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TracingController, feature_category: :tracing do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let(:path) { nil }
  let(:observability_tracing_ff) { true }

  subject do
    get path
    response
  end

  describe 'GET #index' do
    before do
      stub_feature_flags(observability_tracing: observability_tracing_ff)
      sign_in(user)
    end

    let(:path) { project_tracing_index_path(project) }

    it_behaves_like 'observability csp policy' do
      before_all do
        project.add_developer(user)
      end

      let(:tested_path) { path }
    end

    context 'when user does not have permissions' do
      it 'returns 404' do
        expect(subject).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_developer(user)
      end

      it 'returns 200' do
        expect(subject).to have_gitlab_http_status(:ok)
      end

      context 'when feature is disabled' do
        let(:observability_tracing_ff) { false }

        it 'returns 404' do
          expect(subject).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
