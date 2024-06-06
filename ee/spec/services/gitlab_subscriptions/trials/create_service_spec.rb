# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user) }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params) }
    end

    let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    it_behaves_like 'when on the lead step', :free_plan
    it_behaves_like 'when on trial step', :free_plan
    it_behaves_like 'with an unknown step'
    it_behaves_like 'with no step'

    context 'when in the create group flow' do
      let(:step) { described_class::TRIAL }
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
            create(:group_with_plan, plan: :free_plan, name: 'gitlab')

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

    context 'when lead was submitted with an intended namespace' do
      let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
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
      state: 'CA'
    }.merge(extra_lead_params)
  end
end
