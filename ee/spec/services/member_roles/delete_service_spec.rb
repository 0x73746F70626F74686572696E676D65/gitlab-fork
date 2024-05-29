# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::DeleteService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:member_role) { create(:member_role, :guest, namespace: group) }

  subject(:service) { described_class.new(user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe '#execute' do
    subject(:result) { service.execute(member_role) }

    context 'with unauthorized user' do
      it 'returns an error' do
        expect(result).to be_error
      end
    end

    context 'with owner' do
      before_all do
        group.add_owner(user)
      end

      context 'without existing members' do
        it 'is successful' do
          expect(result).to be_success
        end

        it 'deletes the member role' do
          result

          expect(member_role).to be_destroyed
        end

        include_examples 'audit event logging' do
          let(:licensed_features_to_stub) { { custom_roles: true } }
          let(:event_type) { 'member_role_deleted' }
          let(:operation) { result }
          let(:fail_condition!) { allow(member_role).to receive(:destroy).and_return(false) }

          let(:attributes) do
            {
              author_id: user.id,
              entity_id: group.id,
              entity_type: group.class.name,
              details: {
                author_name: user.name,
                target_id: member_role.id,
                target_type: member_role.class.name,
                event_name: "member_role_deleted",
                target_details: {
                  name: member_role.name,
                  description: member_role.description,
                  abilities: member_role.enabled_permissions.join(', ')
                }.to_s,
                custom_message: 'Member role was deleted',
                author_class: user.class.name
              }
            }
          end
        end
      end

      context 'when failing to destroy the member role' do
        before do
          allow(member_role).to receive(:destroy).and_return(false)
          errors = ActiveModel::Errors.new(member_role).tap { |e| e.add(:base, 'error message') }
          allow(member_role).to receive(:errors).and_return(errors)
        end

        it 'returns an array including the error message' do
          expect(result).to be_error
          expect(result.message).to match_array(['error message'])
        end

        it 'does not log an audit event' do
          expect { result }.not_to change { AuditEvent.count }
        end
      end
    end
  end
end
