# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipelines', :js, feature_category: :continuous_integration do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }

  before do
    sign_in(user)

    project.add_developer(user)
  end

  describe 'GET /:project/-/pipelines' do
    describe 'when namespace is in read-only mode' do
      it 'does not render Run pipeline and CI lint link' do
        allow_next_found_instance_of(Namespace) do |instance|
          allow(instance).to receive(:read_only?).and_return(true)
        end

        visit project_pipelines_path(project)
        wait_for_requests
        expect(page).to have_content('Show Pipeline ID')
        expect(page).not_to have_link('CI lint')
        expect(page).not_to have_link('Run pipeline')
      end
    end
  end

  describe 'GET /:project/-/pipelines/new' do
    describe 'when namespace is in read-only mode' do
      it 'renders 404' do
        allow_next_found_instance_of(Namespace) do |instance|
          allow(instance).to receive(:read_only?).and_return(true)
        end

        visit new_project_pipeline_path(project)
        expect(page).to have_content('Page Not Found')
      end
    end
  end

  describe 'POST /:project/-/pipelines' do
    describe 'identity verification requirement', :js, :saas do
      include IdentityVerificationHelpers

      let_it_be_with_reload(:user) { create(:user, :identity_verification_eligible) }

      before do
        stub_saas_features(identity_verification: true)

        stub_feature_flags(
          ci_require_credit_card_on_free_plan: false,
          ci_require_credit_card_on_trial_plan: false
        )

        visit new_project_pipeline_path(project)
      end

      subject(:run_pipeline) do
        find_by_testid('run-pipeline-button', text: 'Run pipeline').click

        wait_for_requests
      end

      it 'prompts the user to verify their account' do
        expect { run_pipeline }.not_to change { Ci::Pipeline.count }

        expect(page).to have_content('Before you can run pipelines, we need to verify your account.')

        click_on 'Verify my account'

        wait_for_requests

        expect_to_see_identity_verification_page

        solve_arkose_verify_challenge

        verify_phone_number

        click_link 'Next'

        wait_for_requests

        run_pipeline

        expect(page).not_to have_content('Before you can run pipelines, we need to verify your account.')
      end
    end
  end
end
