# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Root cause analysis job page', :js, feature_category: :continuous_integration do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:passed_job) { create(:ci_build, :success, :trace_live, project: project) }
  let(:failed_job) { create(:ci_build, :failed, :trace_live, project: project) }

  before do
    stub_licensed_features(ai_analyze_ci_job_failure: true)

    allow(Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)

    project.add_developer(user)
    sign_in(user)
  end

  context 'when root_cause_analysis_duo feature flag is turned off' do
    before do
      stub_feature_flags(root_cause_analysis_duo: false)
    end

    context 'with failed jobs' do
      before do
        allow(failed_job).to receive(:debug_mode?).and_return(false)

        visit(project_job_path(project, failed_job))

        wait_for_requests
      end

      it 'does display rca button' do
        expect(page).to have_selector("[data-testid='rca-button']")
      end
    end

    context 'with successful jobs' do
      before do
        allow(passed_job).to receive(:debug_mode?).and_return(false)

        visit(project_job_path(project, passed_job))

        wait_for_requests
      end

      it 'does not display rca button' do
        expect(page).not_to have_selector("[data-testid='rca-button']")
      end
    end

    context 'without duo_features_enabled permissions' do
      before do
        project.update!(duo_features_enabled: false)

        visit(project_job_path(project, passed_job))

        wait_for_requests
      end

      it 'does not display rca button' do
        expect(page).not_to have_selector("[data-testid='rca-button']")
      end
    end
  end

  context 'when root_cause_analysis_duo feature flag is turned on' do
    before do
      stub_feature_flags(root_cause_analysis_duo: true)
    end

    context 'with failed jobs' do
      before do
        allow(failed_job).to receive(:debug_mode?).and_return(false)

        visit(project_job_path(project, failed_job))

        wait_for_requests
      end

      it 'does display rca with duo button' do
        expect(page).to have_selector("[data-testid='rca-duo-button']")
      end
    end
  end
end
