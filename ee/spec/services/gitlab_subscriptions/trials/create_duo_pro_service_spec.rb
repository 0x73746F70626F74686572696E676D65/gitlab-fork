# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateDuoProService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user, preferred_language: 'en') }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params) }
    end

    let(:lead_service_class) { GitlabSubscriptions::Trials::CreateDuoProLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyDuoProService }

    before_all do
      create(:gitlab_subscription_add_on, :gitlab_duo_pro)
    end

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    it_behaves_like 'when on the lead step', :ultimate_plan
    it_behaves_like 'when on trial step', :ultimate_plan
    it_behaves_like 'with an unknown step'
    it_behaves_like 'with no step'

    context 'for tracking the lead step', :clean_gitlab_redis_shared_state do
      let_it_be(:namespace) do
        create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab') { |record| record.add_owner(user) }
      end

      it 'tracks when lead creation is successful' do
        expect_create_lead_success(trial_user_params)
        expect_apply_trial_fail(user, namespace, extra_params: existing_group_attrs(namespace))

        expect { execute }.to trigger_internal_events(
          'duo_pro_lead_creation_success'
        ).with(user: user, category: 'InternalEventTracking')
        .and trigger_internal_events(
          'duo_pro_trial_registration_failure'
        ).with(user: user, namespace: namespace, category: 'InternalEventTracking')
        .and not_trigger_internal_events(
          'duo_pro_trial_registration_success',
          'duo_pro_lead_creation_failure'
        ).and increment_usage_metrics(
          'counts.count_total_duo_pro_lead_creation_success',
          'counts.count_total_duo_pro_trial_registration_failure'
        ).and not_increment_usage_metrics(
          'counts.count_total_duo_pro_trial_registration_success',
          'counts.count_total_duo_pro_lead_creation_failure'
        )
      end

      it 'tracks when lead creation fails' do
        expect_create_lead_fail(trial_user_params)

        expect { execute }.to trigger_internal_events(
          'duo_pro_lead_creation_failure'
        ).with(user: user, category: 'InternalEventTracking')
        .and not_trigger_internal_events(
          'duo_pro_lead_creation_success',
          'duo_pro_trial_registration_failure',
          'duo_pro_trial_registration_success'
        ).and increment_usage_metrics(
          'counts.count_total_duo_pro_lead_creation_failure'
        ).and not_increment_usage_metrics(
          'counts.count_total_duo_pro_lead_creation_success',
          'counts.count_total_duo_pro_trial_registration_failure',
          'counts.count_total_duo_pro_trial_registration_success'
        )
      end
    end

    context 'for tracking the trial step', :clean_gitlab_redis_shared_state do
      let(:step) { described_class::TRIAL }
      let_it_be(:namespace) do
        create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab') { |record| record.add_owner(user) }
      end

      let(:namespace_id) { namespace.id.to_s }
      let(:extra_params) { { trial_entity: '_entity_' } }
      let(:trial_params) { { namespace_id: namespace_id }.merge(extra_params) }

      it 'tracks when trial registration is successful' do
        expect_apply_trial_success(user, namespace, extra_params: extra_params.merge(existing_group_attrs(namespace)))

        expect { execute }.to trigger_internal_events(
          'duo_pro_trial_registration_success'
        ).with(user: user, namespace: namespace, category: 'InternalEventTracking')
        .and not_trigger_internal_events(
          'duo_pro_lead_creation_success',
          'duo_pro_lead_creation_failure',
          'duo_pro_trial_registration_failure'
        ).and increment_usage_metrics(
          'counts.count_total_duo_pro_trial_registration_success'
        ).and not_increment_usage_metrics(
          'counts.count_total_duo_pro_lead_creation_success',
          'counts.count_total_duo_pro_lead_creation_failure'
        )
      end

      it 'tracks when trial registration fails' do
        expect_apply_trial_fail(user, namespace, extra_params: extra_params.merge(existing_group_attrs(namespace)))

        expect { execute }.to trigger_internal_events(
          'duo_pro_trial_registration_failure'
        ).with(user: user, namespace: namespace, category: 'InternalEventTracking')
        .and not_trigger_internal_events(
          'duo_pro_lead_creation_success',
          'duo_pro_lead_creation_failure',
          'duo_pro_trial_registration_success'
        ).and increment_usage_metrics(
          'counts.count_total_duo_pro_trial_registration_failure'
        ).and not_increment_usage_metrics(
          'counts.count_total_duo_pro_lead_creation_success',
          'counts.count_total_duo_pro_lead_creation_failure',
          'counts.count_total_duo_pro_trial_registration_success'
        )
      end
    end

    context 'when namespace_id is provided' do
      let_it_be(:namespace) do
        create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab') { |record| record.add_owner(user) }
      end

      let(:trial_params) { { namespace_id: namespace.id.to_s } }

      context 'when it is an eligible namespace' do
        before do
          expect_create_lead_success(trial_user_params)
          expect_apply_trial_success(user, namespace, extra_params: existing_group_attrs(namespace))
        end

        it { is_expected.to be_success }
      end

      context 'when it is not an eligible namespace' do
        let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

        specify do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end
    end
  end

  def lead_params(user, extra_lead_params)
    {
      company_name: 'GitLab',
      company_size: '1-99',
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: '+1 23 456-78-90',
      country: 'US',
      work_email: user.email,
      uid: user.id,
      setup_for_company: user.setup_for_company,
      skip_email_confirmation: true,
      gitlab_com_trial: true,
      provider: 'gitlab',
      product_interaction: 'duo_pro_trial',
      preferred_language: 'English',
      opt_in: user.onboarding_status_email_opt_in
    }.merge(extra_lead_params)
  end
end
