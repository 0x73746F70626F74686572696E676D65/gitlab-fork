# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/welcome/show', feature_category: :onboarding do
  let(:invite?) { false }
  let(:trial?) { false }
  let(:onboarding_status) do
    instance_double(
      ::Onboarding::Status,
      invite?: invite?, enabled?: true, subscription?: false, trial?: trial?, oauth?: false,
      setup_for_company_label_text: '_text_',
      welcome_submit_button_text: '_button_text_'
    )
  end

  before do
    allow(view).to receive(:onboarding_status).and_return(onboarding_status)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user))
    allow(view).to receive(:glm_tracking_params).and_return({})

    render
  end

  subject { rendered }

  context 'with basic form items' do
    it 'the text for the :setup_for_company label' do
      is_expected.to have_selector('label[for="user_setup_for_company"]', text: '_text_')
    end

    it 'shows the text for the submit button' do
      is_expected.to have_button('_button_text_')
    end

    it 'has the joining_project fields' do
      is_expected.to have_selector('#joining_project_true')
    end

    it 'has the hidden opt in to email field' do
      is_expected.to have_selector('input[name="user[onboarding_status_email_opt_in]"]')
    end

    it 'renders a select and text field for additional information' do
      is_expected.to have_selector('select[name="user[registration_objective]"]')
      is_expected.to have_selector('input[name="jobs_to_be_done_other"]', visible: false)
    end
  end

  context 'when it is an invite' do
    let(:invite?) { true }

    it 'does not have setup_for_company label' do
      is_expected.not_to have_selector('label[for="user_setup_for_company"]')
    end

    it 'has a hidden input for setup_for_company' do
      is_expected.to have_field('user[setup_for_company]', type: :hidden)
    end

    it 'does not have the joining_project fields' do
      is_expected.not_to have_selector('#joining_project_true')
    end

    it 'does not have opt in to email field' do
      is_expected.not_to have_selector('input[name="user[onboarding_status_email_opt_in]"]')
    end
  end

  context 'when it is a trial' do
    let(:trial?) { true }

    it 'has setup_for_company label' do
      is_expected.to have_selector('label[for="user_setup_for_company"]')
    end

    it 'does not have the joining_project fields' do
      is_expected.not_to have_selector('#joining_project_true')
    end
  end
end
