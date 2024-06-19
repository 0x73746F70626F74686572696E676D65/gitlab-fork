# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a namespace filter for instance level external audit event destinations', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:filter) do
    create(:audit_events_streaming_instance_namespace_filters, external_streaming_destination: destination,
      namespace: group)
  end

  let(:mutation) { graphql_mutation(:audit_events_instance_destination_namespace_filter_delete, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_instance_destination_namespace_filter_delete) }

  let(:input) do
    { namespaceFilterId: filter.to_gid }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      let_it_be(:current_user) { create(:admin) }

      context 'when namespace filter id is valid' do
        it 'deletes the filter', :aggregate_failures do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
            name: 'deleted_instance_namespace_filter',
            author: current_user,
            scope: an_instance_of(Gitlab::Audit::InstanceScope),
            target: destination,
            message: "Deleted namespace filter for instance audit event streaming destination."))
                                                             .once.and_call_original

          expect { mutate }.to change { AuditEvents::Instance::NamespaceFilter.count }.by(-1)

          expect(destination.reload.namespace_filters).to be_empty
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['namespaceFilter']).to be nil
        end
      end

      context 'when namespace filter id is invalid' do
        let(:input) do
          { namespaceFilterId: 'gid://gitlab/AuditEvents::Instance::NamespaceFilter/invalid_id' }
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'when current user is not instance admin' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
