# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'when on the lead step' do
  context 'when lead creation is successful' do
    context 'when there is only one trial eligible namespace' do
      let_it_be(:group) { create(:group, name: 'gitlab').tap { |record| record.add_owner(user) } }

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
        create(:group).tap { |record| record.add_owner(user) }
        create(:group, name: 'gitlab').tap { |record| record.add_owner(user) }
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

      context 'when lead was submitted with an intended namespace' do
        let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

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

RSpec.shared_examples 'with tracking duo pro trial lead' do
  let_it_be(:group) { create(:group, name: 'gitlab').tap { |record| record.add_owner(user) } }

  context 'when lead creation is successful regardless' do
    before do
      expect_create_lead_success(trial_user_params)
      expect_apply_trial_fail(user, group, extra_params: existing_group_attrs(group))
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'duo_pro_lead_creation_success' }
      let(:namespace) { group }

      subject(:track_event) do
        execute
      end
    end
  end

  context 'when lead creation fails' do
    before do
      expect_create_lead_fail(trial_user_params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'duo_pro_lead_creation_failure' }

      subject(:track_event) do
        execute
      end
    end
  end
end

def expect_create_lead_success(trial_user_params)
  expect_next_instance_of(lead_service_class) do |instance|
    expect(instance).to receive(:execute).with(trial_user_params).and_return(ServiceResponse.success)
  end
end

def expect_create_lead_fail(trial_user_params)
  expect_next_instance_of(lead_service_class) do |instance|
    expect(instance).to receive(:execute).with(trial_user_params)
                                         .and_return(ServiceResponse.error(message: '_lead_fail_'))
  end
end

def stub_lead_without_trial(trial_user_params)
  expect_create_lead_success(trial_user_params)
  expect(apply_trial_service_class).not_to receive(:new)
end

def expect_to_trigger_trial_step(execution, lead_payload_params, trial_payload_params)
  expect(execution).to be_error
  expect(execution.reason).to eq(:no_single_namespace)
  trial_selection_params = {
    step: described_class::TRIAL
  }.merge(lead_payload_params).merge(trial_payload_params.slice(:namespace_id))
  expect(execution.payload).to match(trial_selection_params: trial_selection_params)
end

RSpec.shared_examples 'when on trial step' do
  let(:step) { described_class::TRIAL }

  context 'in the existing namespace flow' do
    let_it_be(:group) { create(:group, name: 'gitlab').tap { |record| record.add_owner(user) } }
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
      let(:namespace_id) { create(:group).id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when the user is not an owner of the namespace' do
      let(:namespace_id) { create(:group).tap { |record| record.add_developer(user) }.id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when there is no namespace with the namespace_id' do
      let(:namespace_id) { non_existing_record_id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end
  end

  context 'in the create group flow' do
    let(:extra_params) { { trial_entity: '_entity_' } }
    let(:trial_params) { { new_group_name: 'gitlab', namespace_id: '0' }.merge(extra_params) }

    context 'when group is successfully created' do
      context 'when trial creation is successful' do
        it 'return success with the namespace' do
          expect_next_instance_of(apply_trial_service_class) do |instance|
            expect(instance).to receive(:execute).and_return(ServiceResponse.success)
          end

          expect { execute }.to change { Group.count }.by(1)

          expect(execute).to be_success
          expect(execute.payload).to eq({ namespace: Group.last })
        end
      end

      context 'when trial creation fails' do
        it 'returns an error indicating trial failed' do
          stub_apply_trial(
            user, namespace_id: anything, success: false, extra_params: extra_params.merge(new_group_attrs)
          )

          expect { execute }.to change { Group.count }.by(1)

          expect(execute).to be_error
          expect(execute.payload).to eq({ namespace_id: Group.last.id })
        end
      end

      context 'when group name needs sanitized' do
        it 'return success with the namespace path sanitized for duplication' do
          create(:group, name: 'gitlab')

          stub_apply_trial(
            user, namespace_id: anything, success: true,
            extra_params: extra_params.merge(new_group_attrs(path: 'gitlab1'))
          )

          expect { execute }.to change { Group.count }.by(1)

          expect(execute).to be_success
          expect(execute.payload[:namespace].path).to eq('gitlab1')
        end
      end
    end

    context 'when user is not allowed to create groups' do
      before do
        user.can_create_group = false
      end

      it 'returns not_found' do
        expect(apply_trial_service_class).not_to receive(:new)

        expect { execute }.not_to change { Group.count }
        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when group creation had an error' do
      context 'when there are invalid characters used' do
        let(:trial_params) { { new_group_name: ' _invalid_ ', namespace_id: '0' } }

        it 'returns namespace_create_failed' do
          expect(apply_trial_service_class).not_to receive(:new)

          expect { execute }.not_to change { Group.count }
          expect(execute).to be_error
          expect(execute.reason).to eq(:namespace_create_failed)
          expect(execute.message.to_sentence).to match(/^Group URL can only include non-accented letters/)
          expect(execute.payload[:namespace_id]).to eq('0')
        end
      end

      context 'when name is entered with blank spaces' do
        let(:trial_params) { { new_group_name: '  ', namespace_id: '0' } }

        it 'returns namespace_create_failed' do
          expect(apply_trial_service_class).not_to receive(:new)

          expect { execute }.not_to change { Group.count }
          expect(execute).to be_error
          expect(execute.reason).to eq(:namespace_create_failed)
          expect(execute.message.to_sentence).to match(/^Name can't be blank/)
          expect(execute.payload[:namespace_id]).to eq('0')
        end
      end
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

def stub_apply_trial(user, namespace_id: anything, success: true, extra_params: {})
  trial_user_params = {
    namespace_id: namespace_id,
    gitlab_com_trial: true,
    sync_to_gl: true
  }.merge(extra_params)

  service_params = {
    trial_user_information: trial_user_params,
    uid: user.id
  }

  trial_success = if success
                    ServiceResponse.success
                  else
                    ServiceResponse.error(message: '_trial_fail_')
                  end

  expect_next_instance_of(apply_trial_service_class, service_params) do |instance|
    expect(instance).to receive(:execute).and_return(trial_success)
  end
end

def expect_apply_trial_success(user, group, extra_params: {})
  stub_apply_trial(user, namespace_id: group.id, success: true, extra_params: extra_params)
end

def expect_apply_trial_fail(user, group, extra_params: {})
  stub_apply_trial(user, namespace_id: group.id, success: false, extra_params: extra_params)
end

def existing_group_attrs(group)
  { namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on) }
end

def new_group_attrs(path: 'gitlab')
  {
    namespace: {
      id: anything,
      path: path,
      name: 'gitlab',
      kind: 'group',
      trial_ends_on: nil
    }
  }
end
