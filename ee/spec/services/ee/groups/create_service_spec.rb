# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::CreateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let(:current_user) { user }
  let(:group_params) do
    {
      name: 'GitLab',
      path: 'group_path',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC
    }.merge(extra_params)
  end

  let(:extra_params) { {} }
  let(:created_group) { response[:group] }

  subject(:response) { described_class.new(current_user, group_params).execute }

  context 'for audit events' do
    include_examples 'audit event logging' do
      let_it_be(:event_type) { Groups::CreateService::AUDIT_EVENT_TYPE }
      let(:operation) { response }
      let(:fail_condition!) do
        allow(Gitlab::VisibilityLevel).to receive(:allowed_for?).and_return(false)
      end

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: created_group.id,
          entity_type: 'Group',
          details: {
            author_name: user.name,
            event_name: "group_created",
            target_id: created_group.id,
            target_type: 'Group',
            target_details: created_group.full_path,
            custom_message: Groups::CreateService::AUDIT_EVENT_MESSAGE,
            author_class: user.class.name
          }
        }
      end
    end
  end

  context 'when created group is a sub-group' do
    let_it_be(:group) { create(:group, owners: user) }
    let(:extra_params) { { parent_id: group.id } }

    include_examples 'sends streaming audit event'

    describe 'handling of allow_runner_registration_token' do
      context 'when on SaaS', :saas do
        it 'uses the default value for column' do
          expect(created_group.allow_runner_registration_token).to eq true
        end
      end
    end
  end

  context 'when user has exceed the group creation limit' do
    before do
      allow(user).to receive(:requires_identity_verification_to_create_group?).and_return(true)
    end

    it 'does not create the group', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with({
        message: 'User has reached group creation limit',
        reason: 'Identity verification required',
        class: 'Groups::CreateService',
        username: user.username
      })
      expect { response }.not_to change { Group.count }
      expect(response).to be_error
      expect(response[:group].errors[:identity_verification].first)
        .to eq(s_('CreateGroup|You have reached the group limit until you verify your account.'))
    end
  end

  context 'for repository_size_limit assignment as Bytes' do
    let_it_be(:admin_user) { create(:admin) }

    context 'when the user is an admin with admin mode enabled', :enable_admin_mode do
      let(:current_user) { admin_user }

      context 'when the param is present' do
        let(:extra_params) { { repository_size_limit: '100' } }

        it 'assigns repository_size_limit as Bytes' do
          expect(created_group.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:extra_params) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          expect(created_group.repository_size_limit).to be_nil
        end
      end
    end

    context 'when the user is an admin with admin mode disabled' do
      let(:extra_params) { { repository_size_limit: '100' } }
      let(:current_user) { admin_user }

      it 'assigns a nil value' do
        expect(created_group.repository_size_limit).to be_nil
      end
    end

    context 'when the user is not an admin' do
      let(:extra_params) { { repository_size_limit: '100' } }

      it 'assigns a nil value' do
        expect(created_group.repository_size_limit).to be_nil
      end
    end
  end

  context 'when updating protected params' do
    let(:extra_params) do
      { shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 100 }
    end

    context 'as an admin' do
      let_it_be(:current_user) { create(:admin) }

      it 'updates the attributes' do
        expect(created_group.shared_runners_minutes_limit).to eq(1000)
        expect(created_group.extra_shared_runners_minutes_limit).to eq(100)
      end
    end

    context 'as a regular user' do
      it 'ignores the attributes' do
        expect(created_group.shared_runners_minutes_limit).to be_nil
        expect(created_group.extra_shared_runners_minutes_limit).to be_nil
      end
    end
  end

  context 'with push rule' do
    context 'when feature is available' do
      before do
        stub_licensed_features(push_rules: true)
      end

      context 'when there are push rules settings' do
        let_it_be(:sample) { create(:push_rule_sample) }

        it 'uses the configured push rules settings' do
          expect(created_group.push_rule).to be_nil
          expect(created_group.predefined_push_rule).to eq(sample)
        end
      end

      context 'when there are not push rules settings' do
        it 'is does not create the group push rule' do
          expect(created_group.push_rule).to be_nil
        end
      end
    end

    context 'when feature not is available' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'ignores the group push rule' do
        expect(created_group.push_rule).to be_nil
      end
    end
  end

  describe 'handling of allow_runner_registration_token default' do
    context 'when on SaaS', :saas do
      it 'disallows runner registration tokens' do
        expect(created_group.allow_runner_registration_token?).to eq false
      end
    end
  end
end
