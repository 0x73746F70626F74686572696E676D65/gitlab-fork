# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update an external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:destination) { create(:external_audit_event_destination, name: "Old Destination", destination_url: "https://example.com/old", group: group) }

  let(:current_user) { owner }

  let(:input) do
    {
      id: GitlabSchema.id_from_object(destination).to_s,
      destinationUrl: "https://example.com/new",
      name: "New Destination"
    }
  end

  let(:mutation) { graphql_mutation(:external_audit_event_destination_update, input) }

  let(:mutation_response) { graphql_mutation_response(:external_audit_event_destination_update) }

  shared_examples 'a mutation that does not update a destination' do
    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { destination.reload.destination_url }
    end

    it 'does not audit the update' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEvent.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner but destination belongs to another group' do
      before do
        group.add_owner(owner)
        destination.update!(group: create(:group))
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group owner of a different group' do
      before do
        group_2 = create(:group)
        group_2.add_owner(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
      end

      it 'updates the destination_url' do
        expect do
          post_graphql_mutation(mutation, current_user: owner)
        end.to change { destination.reload.destination_url }.to("https://example.com/new")
      end

      it 'updates the destination name' do
        expect do
          post_graphql_mutation(mutation, current_user: owner)
        end.to change { destination.reload.name }.to("New Destination")
      end

      it_behaves_like 'audits update to external streaming destination' do
        let_it_be(:current_user) { owner }
      end

      context 'when there is no change in values' do
        let(:input) do
          {
            id: GitlabSchema.id_from_object(destination).to_s,
            destinationUrl: destination.reload.destination_url
          }
        end

        it_behaves_like 'a mutation that does not update a destination'
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { destination.reload.destination_url }
    end
  end
end
