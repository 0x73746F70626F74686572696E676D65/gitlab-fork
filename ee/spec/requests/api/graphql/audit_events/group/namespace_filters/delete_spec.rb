# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a namespace filter for group level external audit event destinations', feature_category: :audit_events do
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:group) { create(:group) }
  let(:subgroup) { create(:group, parent: group) }
  let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
  let!(:filter) do
    create(:audit_events_streaming_group_namespace_filters, external_streaming_destination: destination,
      namespace: subgroup)
  end

  let(:mutation) { graphql_mutation(:audit_events_group_destination_namespace_filter_delete, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_group_destination_namespace_filter_delete) }

  let(:input) do
    { namespaceFilterId: filter.to_gid }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'does not delete the namespace filter' do
    it do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
                                                .with(a_hash_including(name: 'deleted_group_namespace_filter'))

      expect { subject }.not_to change { destination.reload.namespace_filters.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is group owner' do
      before do
        group.add_owner(current_user)
      end

      it 'deletes the filter', :aggregate_failures do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
          name: 'deleted_group_namespace_filter',
          author: current_user,
          scope: group,
          target: destination,
          message: "Deleted namespace filter for group audit event streaming destination."))
                                                           .once.and_call_original

        expect { mutate }.to change { AuditEvents::Group::NamespaceFilter.count }.by(-1)

        expect(destination.reload.namespace_filters).to be_empty
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['namespaceFilter']).to be nil
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'does not delete the namespace filter'
    end
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it_behaves_like 'does not delete the namespace filter'
  end
end
