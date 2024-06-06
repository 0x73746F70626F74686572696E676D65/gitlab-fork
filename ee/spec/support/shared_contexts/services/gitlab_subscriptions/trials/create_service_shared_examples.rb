# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'when on the lead step' do |plan_name|
  context 'when lead creation is successful' do
    context 'when there is only one trial eligible namespace' do
      let_it_be(:group) do
        create(:group_with_plan, plan: plan_name, name: 'gitlab') { |record| record.add_owner(user) }
      end

      it 'starts a trial and tracks the event' do
        expect_create_lead_success(trial_user_params)
        expect_apply_trial_success(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_success
        expect(execute.payload).to eq({ namespace: group })
        expect_snowplow_event(category: described_class.name, action: 'create_trial', namespace: group, user: user)
      end

      it 'errors when trying to apply a trial' do
        expect_create_lead_success(trial_user_params)
        expect_apply_trial_fail(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_error
        expect(execute.reason).to eq(:trial_failed)
        expect(execute.payload).to eq({ namespace_id: group.id })
        expect_no_snowplow_event(
          category: described_class.name, action: 'create_trial', namespace: group, user: user
        )
      end
    end

    context 'when there are no trial eligible namespaces' do
      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end

      context 'with glm params' do
        let(:extra_lead_params) { { glm_content: '_glm_content_', glm_source: '_glm_source_' } }

        it 'does not create a trial and returns that there is no namespace' do
          stub_lead_without_trial(trial_user_params)

          expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
        end
      end
    end

    context 'when there are multiple trial eligible namespaces' do
      let_it_be(:group) do
        create(:group_with_plan, plan: plan_name) { |record| record.add_owner(user) }
        create(:group_with_plan, plan: plan_name, name: 'gitlab') { |record| record.add_owner(user) }
      end

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end

      context 'with glm params' do
        let(:extra_lead_params) { { glm_content: '_glm_content_', glm_source: '_glm_source_' } }

        it 'does not create a trial and returns that there is no namespace' do
          stub_lead_without_trial(trial_user_params)

          expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
        end
      end
    end

    context 'when lead creation fails' do
      it 'returns and error indicating lead failed' do
        expect_create_lead_fail(trial_user_params)
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:lead_failed)
      end
    end
  end
end

RSpec.shared_examples 'when on trial step' do |plan_name|
  let(:step) { described_class::TRIAL }

  context 'in the existing namespace flow' do
    let_it_be(:group) { create(:group_with_plan, plan: plan_name, name: 'gitlab') { |record| record.add_owner(user) } }
    let(:namespace_id) { group.id.to_s }
    let(:extra_params) { { trial_entity: '_entity_' } }
    let(:trial_params) { { namespace_id: namespace_id }.merge(extra_params) }

    shared_examples 'starts a trial' do
      it do
        expect_apply_trial_success(user, group, extra_params: extra_params.merge(existing_group_attrs(group)))

        expect(execute).to be_success
        expect(execute.payload).to eq({ namespace: group })
      end
    end

    shared_examples 'returns an error of not_found and does not apply a trial' do
      it do
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when trial creation is successful' do
      it_behaves_like 'starts a trial'

      context 'when a valid namespace_id of non zero and new_group_name is present' do
        # This can *currently* happen on validation failure for creating
        # a new namespace.
        let(:trial_params) { { new_group_name: 'gitlab', namespace_id: group.id, trial_entity: '_entity_' } }

        context 'with the namespace_id' do
          it_behaves_like 'starts a trial'
        end
      end
    end

    context 'when trial creation is not successful' do
      it 'returns an error indicating trial failed' do
        expect_apply_trial_fail(user, group, extra_params: extra_params.merge(existing_group_attrs(group)))

        expect(execute).to be_error
        expect(execute.reason).to eq(:trial_failed)
      end
    end

    context 'when the user does not have access to the namespace' do
      let(:namespace_id) { create(:group_with_plan, plan: plan_name).id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when the user is not an owner of the namespace' do
      let(:namespace_id) { create(:group_with_plan, plan: plan_name) { |record| record.add_developer(user) }.id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when there is no namespace with the namespace_id' do
      let(:namespace_id) { non_existing_record_id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end
  end

  context 'when namespace_id is 0 without a new_group_name' do
    let(:trial_params) { { namespace_id: '0' } }

    it 'returns an error of not_found and does not apply a trial' do
      expect(apply_trial_service_class).not_to receive(:new)

      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end

  context 'when neither new group name or namespace_id is present' do
    let(:trial_params) { {} }

    it 'returns an error of not_found and does not apply a trial' do
      expect(apply_trial_service_class).not_to receive(:new)

      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end
end

RSpec.shared_examples 'with an unknown step' do
  let(:step) { 'bogus' }

  it_behaves_like 'returns an error of not_found and does not create lead or apply a trial'
end

RSpec.shared_examples 'with no step' do
  let(:step) { nil }

  it_behaves_like 'returns an error of not_found and does not create lead or apply a trial'
end

RSpec.shared_examples 'returns an error of not_found and does not create lead or apply a trial' do
  it do
    expect(lead_service_class).not_to receive(:new)
    expect(apply_trial_service_class).not_to receive(:new)

    expect(execute).to be_error
    expect(execute.reason).to eq(:not_found)
  end
end
