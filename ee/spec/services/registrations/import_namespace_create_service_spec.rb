# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::ImportNamespaceCreateService, :aggregate_failures, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user, reload: true) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:extra_params) { {} }
    let(:group_params) do
      {
        name: 'Group name',
        path: 'group-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s
      }
    end

    let(:params) do
      ActionController::Parameters.new({ group: group_params, import_url: '_import_url_' }.merge(extra_params))
    end

    before_all do
      group.add_owner(user)
    end

    subject(:execute) { described_class.new(user, params).execute }

    context 'when group can be created' do
      it 'creates a group' do
        expect do
          expect(execute).to be_success
        end.to change { Group.count }.by(1).and change { ::Onboarding::Progress.count }.by(1)
      end

      it 'passes setup_for_company to the Groups::CreateService' do
        added_params = { setup_for_company: nil }

        expect(Groups::CreateService).to receive(:new)
                                           .with(user, ActionController::Parameters
                                                         .new(group_params.merge(added_params)).permit!)
                                           .and_call_original

        expect(execute).to be_success
      end

      it 'enqueues a create event worker' do
        expect(Groups::CreateEventWorker).to receive(:perform_async).with(anything, user.id, :created)

        execute
      end

      it 'tracks group creation events' do
        expect(execute).to be_success

        expect_snowplow_event(
          category: described_class.name,
          action: 'create_group_import',
          namespace: an_instance_of(Group),
          user: user
        )
      end

      it 'does not attempt to create a trial' do
        expect(GitlabSubscriptions::Trials::ApplyTrialWorker).not_to receive(:perform_async)

        expect(execute).to be_success
      end
    end

    context 'when the group cannot be created' do
      let(:group_params) { { name: '', path: '' } }

      it 'does not create a group' do
        expect do
          expect(execute).to be_error
        end.to change { Group.count }.by(0).and change { ::Onboarding::Progress.count }.by(0)
        expect(execute.payload[:group].errors).not_to be_blank
      end

      it 'does not track events for group creation' do
        expect(execute).to be_error

        expect_no_snowplow_event(category: described_class.name, action: 'create_group_import')
      end

      it 'the project is not disregarded completely' do
        expect(execute).to be_error

        expect(execute.payload[:project].namespace).to be_present
      end

      it 'does not enqueue a create event worker' do
        expect(Groups::CreateEventWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'with applying for a trial' do
      let(:extra_params) do
        { glm_source: 'about.gitlab.com', glm_content: 'content' }
      end

      let(:trial_user_information) do
        ActionController::Parameters.new(
          {
            glm_source: 'about.gitlab.com',
            glm_content: 'content',
            namespace_id: group.id,
            gitlab_com_trial: true,
            sync_to_gl: true,
            namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on)
          }
        )
      end

      before do
        allow_next_instance_of(::Groups::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { group: group }))
        end

        stub_saas_features(onboarding: true)
        user.update!(onboarding_status_registration_type: 'trial')
      end

      it 'applies a trial' do
        expect(GitlabSubscriptions::Trials::ApplyTrialWorker).to receive(:perform_async)
                                                                   .with(user.id, trial_user_information)
                                                                   .and_call_original

        expect(execute).to be_success
      end
    end
  end
end
