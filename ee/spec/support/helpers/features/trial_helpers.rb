# frozen_string_literal: true

require 'support/helpers/listbox_helpers'

module Features
  module TrialHelpers
    include ListboxHelpers
    DUO_PRO_TRIAL = 'duo_pro_trial'

    def expect_to_be_on_group_page(path: 'gitlab', name: 'gitlab')
      expect(page).to have_current_path("/#{path}?trial=true")
      within_testid('super-sidebar') do
        expect(page).to have_selector('a[aria-current="page"]', text: name)
      end
    end

    def expect_to_be_on_namespace_selection_with_errors
      expect_to_be_on_namespace_selection
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('Please try again or reach out to GitLab Support.')
      expect(page).to have_link('GitLab Support', href: 'https://support.gitlab.com/hc/en-us')
    end

    def expect_to_be_on_namespace_selection
      expect(page).to have_content('This trial is for')
      expect(page).to have_content('Who will be using GitLab?')
    end

    def expect_to_have_namespace_creation_errors(group_name: '_invalid group name_', error_message: 'Group URL can')
      within('[data-testid="trial-form"]') do
        expect(page).not_to have_content('This trial is for')
        expect(page.find_field('new_group_name').value).to eq(group_name)
        expect(page).to have_content(error_message)
      end
    end

    def expect_to_be_on_lead_form_with_errors
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('_lead_fail_')
      expect(page).to have_content('Number of employees')

      # This is needed to ensure the countries and regions selector has time to populate
      # This only happens on the duo trial and not the regular trial. Probably due to the added time for full page
      # to load with background on duo trial. However, this wait should be present anyway to avoid possible flakiness.
      wait_for_all_requests
    end

    def expect_to_be_on_group_security_dashboard(group_for_path: group)
      expect(page).to have_current_path(group_security_dashboard_path(group_for_path, { trial: true }))
      within_testid('super-sidebar') do
        expect(page).to have_link(group_for_path.name)
      end
    end

    def expect_to_be_on_group_usage_quotas_page(path: 'gitlab', name: 'gitlab')
      expect(page).to have_current_path("/groups/#{path}/-/usage_quotas")
      within_testid('super-sidebar') do
        expect(page).to have_link(name)
      end
    end

    def fill_in_trial_selection_form(from: 'Please select a group', group_select: true)
      select_from_listbox group.name, from: from if group_select
      choose :trial_entity_company
    end

    def fill_in_trial_form_for_new_group(name: 'gitlab', glm_source: nil)
      fill_in 'new_group_name', with: name
      choose :trial_entity_company if glm_source != 'about.gitlab.com'
    end

    def form_data
      {
        phone_number: '+1 23 456-78-90',
        company_size: '1 - 99',
        company_name: 'GitLab',
        country: { id: 'US', name: 'United States of America' },
        state: { id: 'CA', name: 'California' }
      }
    end

    def fill_in_company_information
      fill_in 'company_name', with: form_data[:company_name]
      select form_data[:company_size], from: 'company_size'
      fill_in 'phone_number', with: form_data[:phone_number]
      select form_data.dig(:country, :name), from: 'country'
      select form_data.dig(:state, :name), from: 'state'
    end

    def submit_company_information_form(
      trial_type: '', lead_success: true, trial_success: true, with_trial: false,
      extra_params: {})
      # lead
      trial_user_params = {
        company_name: form_data[:company_name],
        company_size: form_data[:company_size].delete(' '),
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :name)
      }.merge(extra_params)

      if trial_type == DUO_PRO_TRIAL
        trial_user_params = trial_user_params.merge(
          {
            product_interaction: DUO_PRO_TRIAL,
            preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
            opt_in: user.onboarding_status_email_opt_in
          }
        )
      end

      lead_params = {
        trial_user: trial_user_params
      }

      lead_result = if lead_success
                      ServiceResponse.success
                    else
                      ServiceResponse.error(message: '_lead_fail_', reason: :lead_failed)
                    end

      create_lead_class =
        case trial_type
        when DUO_PRO_TRIAL
          GitlabSubscriptions::Trials::CreateDuoProLeadService
        else
          GitlabSubscriptions::CreateLeadService
        end

      expect_next_instance_of(create_lead_class) do |service|
        expect(service).to receive(:execute).with(lead_params).and_return(lead_result)
      end

      # trial
      if with_trial
        stub_apply_trial(
          namespace_id: group.id,
          success: trial_success,
          extra_params: extra_params.merge(existing_group_attrs),
          trial_type: trial_type
        )
      end

      button_text =
        case trial_type
        when DUO_PRO_TRIAL
          'Continue'
        else
          'Start free GitLab Ultimate trial'
        end

      click_button button_text

      wait_for_requests
    end

    def submit_trial_selection_form(success: true, extra_params: {}, trial_type: '')
      stub_apply_trial(
        namespace_id: group.id,
        success: success,
        extra_params: extra_with_glm_source(extra_params).merge(existing_group_attrs),
        trial_type: trial_type
      )

      button_text =
        case trial_type
        when DUO_PRO_TRIAL
          'Activate my trial'
        else
          'Start your free trial'
        end

      click_button button_text
    end

    def submit_new_group_trial_selection_form(success: true, extra_params: {}, trial_type: '')
      stub_apply_trial(success: success, extra_params: extra_with_glm_source(extra_params), trial_type: trial_type)

      button_text =
        case trial_type
        when DUO_PRO_TRIAL
          'Activate my trial'
        else
          'Start your free trial'
        end

      click_button button_text
    end

    def extra_with_glm_source(extra_params)
      extra_params[:trial_entity] = 'company' unless extra_params[:glm_source] == 'about.gitlab.com'

      extra_params
    end

    def existing_group_attrs
      { namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: group.actual_plan.name) }
    end

    def new_group_attrs(path: 'gitlab', name: 'gitlab')
      {
        namespace: {
          id: anything,
          path: path,
          name: name,
          kind: 'group',
          trial_ends_on: nil,
          plan: 'free'
        }
      }
    end

    def stub_apply_trial(trial_type: '', namespace_id: anything, success: true, extra_params: {})
      trial_user_params = {
        namespace_id: namespace_id,
        gitlab_com_trial: true,
        sync_to_gl: true,
        organization_id: anything
      }.merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      trial_success = if success
                        ServiceResponse.success
                      else
                        ServiceResponse.error(message: '_trial_fail_',
                          reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
                      end

      apply_trial_class =
        case trial_type
        when DUO_PRO_TRIAL
          GitlabSubscriptions::Trials::ApplyDuoProService
        else
          GitlabSubscriptions::Trials::ApplyTrialService
        end

      expect_next_instance_of(apply_trial_class, service_params) do |instance|
        expect(instance).to receive(:execute).and_return(trial_success)
      end
    end

    def submit_duo_pro_trial_company_form(**kwargs)
      submit_company_information_form(**kwargs, trial_type: DUO_PRO_TRIAL)
    end

    def submit_duo_pro_trial_selection_form(**kwargs)
      submit_trial_selection_form(**kwargs, trial_type: DUO_PRO_TRIAL)
    end
  end
end
