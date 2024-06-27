# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialsHelper, feature_category: :acquisition do
  using RSpec::Parameterized::TableSyntax

  describe '#create_lead_form_data' do
    let(:user) { build_stubbed(:user, user_detail: build_stubbed(:user_detail, organization: '_org_')) }

    let(:extra_params) do
      {
        first_name: '_params_first_name_',
        last_name: '_params_last_name_',
        company_name: '_params_company_name_',
        company_size: '_company_size_',
        phone_number: '1234',
        country: '_country_',
        state: '_state_'
      }
    end

    let(:params) do
      ActionController::Parameters.new(extra_params.merge(glm_source: '_glm_source_', glm_content: '_glm_content_'))
    end

    before do
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'provides expected form data' do
      keys = extra_params.keys + [:submit_path]

      expect(helper.create_lead_form_data.keys.map(&:to_sym)).to match_array(keys)
    end

    it 'allows overriding data with params' do
      expect(helper.create_lead_form_data).to match(a_hash_including(extra_params))
    end

    context 'when namespace_id is in the params' do
      let(:extra_params) { { namespace_id: non_existing_record_id } }

      it 'provides the submit path with the namespace_id' do
        expect(helper.create_lead_form_data[:submit_path]).to eq(trials_path(step: :lead, **params.permit!))
      end
    end

    context 'when params are empty' do
      let(:extra_params) { {} }

      it 'uses the values from current user' do
        current_user_attributes = {
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.organization
        }

        expect(helper.create_lead_form_data).to match(a_hash_including(current_user_attributes))
      end
    end
  end

  describe '#create_duo_pro_lead_form_data' do
    let(:user) { build_stubbed(:user, user_detail: build_stubbed(:user_detail, organization: '_org_')) }

    let(:extra_params) do
      {
        first_name: '_params_first_name_',
        last_name: '_params_last_name_',
        company_name: '_params_company_name_',
        company_size: '_company_size_',
        phone_number: '1234',
        country: '_country_',
        state: '_state_'
      }
    end

    let(:params) { ActionController::Parameters.new(extra_params) }

    before do
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:current_user).and_return(user)
    end

    subject(:form_data) { helper.create_duo_pro_lead_form_data }

    it 'provides expected form data' do
      keys = extra_params.keys + [:submit_path, :trial_variant]

      expect(form_data.keys.map(&:to_sym)).to match_array(keys)
    end

    it 'allows overriding data with params' do
      expect(form_data).to match(a_hash_including(extra_params))
    end

    context 'when namespace_id is in the params' do
      let(:extra_params) { { namespace_id: non_existing_record_id } }

      it 'provides the submit path with the namespace_id' do
        expect(form_data[:submit_path]).to eq(trials_duo_pro_path(step: :lead, **params.permit!))
      end
    end

    context 'when params are empty' do
      let(:extra_params) { {} }

      it 'uses the values from current user' do
        current_user_attributes = {
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.organization
        }

        expect(helper.create_duo_pro_lead_form_data).to match(a_hash_including(current_user_attributes))
      end
    end
  end

  describe '#create_company_form_data' do
    let(:user) { build_stubbed(:user) }
    let(:extra_params) do
      {
        trial: 'true',
        role: '_params_role_',
        registration_objective: '_params_registration_objective_',
        jobs_to_be_done_other: '_params_jobs_to_be_done_other'
      }
    end

    let(:params) do
      ActionController::Parameters.new(extra_params)
    end

    before do
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'allows overriding data with params' do
      attributes = {
        submit_path: "/users/sign_up/company?#{extra_params.to_query}",
        first_name: user.first_name,
        last_name: user.last_name,
        initial_trial: 'false'
      }

      expect(helper.create_company_form_data(::Onboarding::Status.new({}, {}, user))).to match(attributes)
    end
  end

  describe '#should_ask_company_question?' do
    before do
      allow(helper).to receive(:glm_params).and_return(glm_source ? { glm_source: glm_source } : {})
    end

    subject { helper.should_ask_company_question? }

    where(:glm_source, :result) do
      'about.gitlab.com'  | false
      'learn.gitlab.com'  | false
      'docs.gitlab.com'   | false
      'abouts.gitlab.com' | true
      'about.gitlab.org'  | true
      'about.gitlob.com'  | true
      nil                 | true
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#show_tier_badge_for_new_trial?' do
    where(:trials_available?, :paid?, :private?, :never_had_trial?, :authorized, :result) do
      false | false | true | true | true | false
      true | true | true | true | true | false
      true | false | false | true | true | false
      true | false | true | false | true | false
      true | false | true | true | false | false
      true | false | true | true | true | true
    end

    with_them do
      let(:namespace) { build(:namespace) }
      let(:user) { build(:user) }

      before do
        stub_saas_features(subscriptions_trials: trials_available?)
        allow(namespace).to receive(:paid?).and_return(paid?)
        allow(namespace).to receive(:private?).and_return(private?)
        allow(namespace).to receive(:never_had_trial?).and_return(never_had_trial?)
        allow(helper).to receive(:can?).with(user, :read_billing, namespace).and_return(authorized)
      end

      subject { helper.show_tier_badge_for_new_trial?(namespace, user) }

      it { is_expected.to be(result) }
    end
  end

  describe '#glm_params' do
    let(:glm_source) { nil }
    let(:glm_content) { nil }
    let(:params) do
      ActionController::Parameters.new({
        controller: 'FooBar', action: 'stuff', id: '123'
      }.tap do |p|
        p[:glm_source] = glm_source if glm_source
        p[:glm_content] = glm_content if glm_content
      end)
    end

    before do
      allow(helper).to receive(:params).and_return(params)
    end

    subject { helper.glm_params }

    it 'is memoized' do
      expect(helper).to receive(:strong_memoize)

      subject
    end

    where(:glm_source, :glm_content, :result) do
      nil       | nil       | {}
      'source'  | nil       | { glm_source: 'source' }
      nil       | 'content' | { glm_content: 'content' }
      'source'  | 'content' | { glm_source: 'source', glm_content: 'content' }
    end

    with_them do
      it { is_expected.to eq(HashWithIndifferentAccess.new(result)) }
    end
  end

  describe '#glm_source' do
    let(:host) { ::Gitlab.config.gitlab.host }

    it 'return gitlab config host' do
      glm_source = helper.glm_source

      expect(glm_source).to eq(host)
    end
  end

  describe '#namespace_options_for_listbox' do
    let_it_be(:group1) { create :group }
    let_it_be(:group2) { create :group }

    let(:trial_eligible_namespaces) { [] }

    let(:new_optgroup) do
      {
        text: _('New'),
        options: [
          {
            text: _('Create group'),
            value: '0'
          }
        ]
      }
    end

    let(:groups_optgroup) do
      {
        text: _('Groups'),
        options: trial_eligible_namespaces.map { |n| { text: n.name, value: n.id.to_s } }
      }
    end

    subject { helper.namespace_options_for_listbox(trial_eligible_namespaces) }

    context 'when there is no eligible group' do
      it 'returns just the "New" option group', :aggregate_failures do
        is_expected.to match_array([new_optgroup])
      end
    end

    context 'when only group namespaces are eligible' do
      let(:trial_eligible_namespaces) { [group1, group2] }

      it 'returns the "New" and "Groups" option groups', :aggregate_failures do
        is_expected.to match_array([new_optgroup, groups_optgroup])
        expect(subject[1][:options].length).to be(2)
      end
    end

    context 'when some group namespaces are eligible' do
      let(:trial_eligible_namespaces) { [group2] }

      it 'returns the "New", "Groups" option groups', :aggregate_failures do
        is_expected.to match_array([new_optgroup, groups_optgroup])
        expect(subject[1][:options].length).to be(1)
      end
    end
  end

  describe '#trial_selection_intro_text' do
    before do
      allow(helper).to receive(:any_trial_eligible_namespaces?).and_return(have_group_namespace)
    end

    subject { helper.trial_selection_intro_text }

    where(:have_group_namespace, :text) do
      true  | 'You can apply your trial to a new group or an existing group.'
      false | 'Create a new group to start your GitLab Ultimate trial.'
    end

    with_them do
      it { is_expected.to eq(text) }
    end
  end

  context 'with namespace_selector_data', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:free) { create(:group) }
    let_it_be(:premium_subscription) { create(:gitlab_subscription, :premium, :with_group) }
    let_it_be(:ultimate_subscription) { create(:gitlab_subscription, :ultimate, :with_group) }
    let_it_be(:ultimate_trial_subscription) { create(:gitlab_subscription, :ultimate_trial, :with_group) }
    let_it_be(:all_groups) do
      [
        free,
        premium_subscription.namespace,
        ultimate_subscription.namespace,
        ultimate_trial_subscription.namespace
      ]
    end

    let(:parsed_selector_data) { Gitlab::Json.parse(selector_data[:items]) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      all_groups.map { |group| group.add_owner(user) }
    end

    describe '#trial_namespace_selector_data' do
      subject(:selector_data) { helper.trial_namespace_selector_data(nil) }

      it 'returns free group' do
        group_options = [{ 'text' => free.name, 'value' => free.id.to_s }]

        is_expected.to include(any_trial_eligible_namespaces: 'true')
        new_group_option = parsed_selector_data[0]['options']
        group_select_options = parsed_selector_data[1]['options']
        expect(new_group_option).to eq([{ 'text' => _('Create group'), 'value' => '0' }])
        expect(group_select_options).to eq(group_options)
      end
    end

    describe '#duo_pro_trial_namespace_selector_data' do
      let_it_be(:all_groups) do
        [
          premium_subscription.namespace,
          ultimate_subscription.namespace,
          ultimate_trial_subscription.namespace
        ]
      end

      before_all do
        create(:gitlab_subscription_add_on, :gitlab_duo_pro)
      end

      subject(:selector_data) { helper.duo_pro_trial_namespace_selector_data(all_groups, nil) }

      it 'returns all groups without create group option' do
        group_options = all_groups.map do |group|
          { 'text' => group.name, 'value' => group.id.to_s }
        end

        is_expected.to include(any_trial_eligible_namespaces: 'true')
        expect(parsed_selector_data).to eq(group_options)
      end
    end
  end

  describe '#trial_form_errors_message' do
    let(:result) { ServiceResponse.error(message: ['some error']) }

    subject { helper.trial_form_errors_message(result) }

    it 'returns error message from the result directly' do
      is_expected.to eq('some error')
    end

    context 'when the error has :generic_trial_error as reason' do
      let(:result) do
        ServiceResponse.error(message: ['some error'],
          reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
      end

      it 'overrides the error message' do
        is_expected.to include('Please try again or reach out to')
        is_expected.to include(
          '<a target="_blank" rel="noopener noreferrer" href="https://support.gitlab.com/hc/en-us">GitLab Support</a>'
        )
      end
    end
  end
end
