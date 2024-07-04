# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DeployTokens::RevokeService, feature_category: :continuous_delivery do
  let_it_be(:entity) { create(:group) }
  let_it_be(:destination) { create(:external_audit_event_destination, group: entity) }
  let_it_be(:deploy_token) { create(:deploy_token, :group, groups: [entity]) }
  let_it_be(:user) { create(:user) }
  let_it_be(:deploy_token_params) { { id: deploy_token.id } }

  describe '#execute' do
    let(:revoke_service) { described_class.new(entity, user, deploy_token_params) }

    subject(:revoke) { revoke_service.execute }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it "creates an audit event" do
      expect { revoke }.to change { AuditEvent.count }.by(1)

      expected_message = <<~MESSAGE.squish
        Revoked group deploy token with name: #{deploy_token.name}
        with token_id: #{deploy_token.id} with scopes: #{deploy_token.scopes}.
      MESSAGE

      details = AuditEvent.last.details

      expect(details[:custom_message]).to eq(expected_message)
      expect(details[:action]).to eq(:custom)
      expect(details[:revocation_source]).to be_nil
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { "group_deploy_token_revoked" }
    end

    context 'when group is a sub-group' do
      let_it_be(:parent_group) { create :group }
      let_it_be(:group) { create :group, parent: parent_group }
      let_it_be(:deploy_token) { create(:deploy_token, :group, groups: [group]) }
      let_it_be(:deploy_token_params) { { id: deploy_token.id } }

      let(:revoke_service) { described_class.new(group, user, deploy_token_params) }

      before do
        group.add_owner(user)
      end

      include_examples 'sends streaming audit event'
    end

    context 'when source is set' do
      it 'includes source in audit event' do
        revoke_service.source = :group_token_revocation_service

        revoke

        expect(AuditEvent.last.details[:revocation_source]).to eq(:group_token_revocation_service)
      end
    end
  end
end
