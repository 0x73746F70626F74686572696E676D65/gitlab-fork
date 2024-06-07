# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::CreateService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    let(:params) do
      {
        namespace: group,
        name: 'new name', read_vulnerability: true,
        admin_merge_request: true, base_access_level: Gitlab::Access::GUEST
      }
    end

    subject(:create_member_role) { described_class.new(user, params).execute }

    before do
      stub_licensed_features(custom_roles: true)
    end

    shared_examples 'service returns error' do
      it 'is not successful' do
        expect(create_member_role).to be_error
      end

      it 'returns the correct error messages' do
        expect(create_member_role.message).to include(error_message)
      end

      it 'does not create the member role' do
        expect { create_member_role }.not_to change { MemberRole.count }
      end

      it 'does not log an audit event' do
        expect { create_member_role }.not_to change { AuditEvent.count }
      end
    end

    shared_examples 'member role creation' do
      context 'with valid params' do
        it 'is successful' do
          expect(create_member_role).to be_success
        end

        it 'returns the object with assigned attributes' do
          expect(create_member_role.payload[:member_role].name).to eq('new name')
        end

        it 'creates the member role correctly' do
          expect { create_member_role }.to change { MemberRole.count }.by(1)

          member_role = MemberRole.last
          expect(member_role.name).to eq('new name')
          expect(member_role.read_vulnerability).to eq(true)
        end

        include_examples 'audit event logging' do
          let(:licensed_features_to_stub) { { custom_roles: true } }
          let_it_be(:event_type) { 'member_role_created' }
          let(:operation) { create_member_role.payload[:member_role] }

          let(:attributes) do
            {
              author_id: user.id,
              entity_id: audit_entity_id,
              entity_type: audit_entity_type,
              details: {
                author_name: user.name,
                event_name: "member_role_created",
                target_id: operation.id,
                target_type: operation.class.name,
                target_details: {
                  name: operation.name,
                  description: operation.description,
                  abilities: operation.enabled_permissions.join(', ')
                }.to_s,
                custom_message: 'Member role was created',
                author_class: user.class.name
              }
            }
          end
        end
      end

      context 'with invalid params' do
        context 'with a missing param' do
          before do
            params.delete(:base_access_level)
          end

          let(:error_message) { 'Base access level' }

          it_behaves_like 'service returns error'
        end
      end
    end

    context 'for group member roles' do
      let(:audit_entity_id) { group.id }
      let(:audit_entity_type) { 'Group' }
      let(:fail_condition!) do
        allow(group).to receive(:custom_roles_enabled?).and_return(false)
      end

      context 'with unauthorized user', :saas do
        before_all do
          group.add_maintainer(user)
        end

        let(:error_message) { 'Operation not allowed' }

        it_behaves_like 'service returns error'
      end

      context 'with authorized user' do
        before_all do
          group.add_owner(user)
        end

        context 'with root group' do
          context 'when on SaaS', :saas do
            it_behaves_like 'member role creation'
          end

          context 'when on self-managed' do
            let(:error_message) { 'Operation not allowed' }

            it_behaves_like 'service returns error'
          end
        end

        context 'with non-root group', :saas do
          before_all do
            group.update!(parent: create(:group))
          end

          let(:error_message) { 'Creation of member role is allowed only for root groups' }

          it_behaves_like 'service returns error'
        end
      end
    end

    context 'for instance-level member roles' do
      let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
      let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
      let(:fail_condition!) do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(true)
      end

      before do
        params.delete(:namespace)
      end

      context 'with unauthorized user' do
        before_all do
          group.add_owner(user)
        end

        let(:error_message) { 'Operation not allowed' }

        it_behaves_like 'service returns error'
      end

      context 'with authorized user', :enable_admin_mode do
        before_all do
          user.update!(admin: true)
        end

        context 'when on self-managed' do
          it_behaves_like 'member role creation'
        end

        context 'when on SaaS', :saas do
          let(:error_message) { 'Operation not allowed' }

          it_behaves_like 'service returns error'
        end
      end
    end
  end
end
