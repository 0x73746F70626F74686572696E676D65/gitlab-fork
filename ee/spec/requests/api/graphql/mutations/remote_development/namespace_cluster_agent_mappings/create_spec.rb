# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Map a cluster agent to a group', feature_category: :remote_development do
  include GraphqlHelpers
  include StubFeatureFlags

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:namespace) { create(:group).tap { |group| group.add_owner(user) } }
  let_it_be_with_reload(:agent) { create(:cluster_agent, project: create(:project, group: namespace)) }

  let(:mutation) do
    graphql_mutation(:namespace_create_remote_development_cluster_agent_mapping, mutation_args)
  end

  let(:stub_service_payload) { { namespace_cluster_agent_mapping: created_mapping } }
  let(:stub_service_response) { ServiceResponse.success(payload: stub_service_payload) }

  let(:created_mapping) do
    instance_double(RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping)
  end

  let(:all_mutation_args) do
    {
      namespace_id: namespace.to_global_id.to_s,
      cluster_agent_id: agent.to_global_id.to_s
    }
  end

  let(:mutation_args) { all_mutation_args }

  def mutation_response
    graphql_mutation_response(:namespace_create_remote_development_cluster_agent_mapping)
  end

  before do
    stub_licensed_features(remote_development: true)
    allow_next_instance_of(
      ::RemoteDevelopment::NamespaceClusterAgentMappings::CreateService
    ) do |service_instance|
      allow(service_instance).to receive(:execute).with(
        namespace: namespace,
        cluster_agent: agent,
        user: current_user
      ) do
        stub_service_response
      end
    end
  end

  context 'when the params are valid' do
    context 'when user has owner access to the group' do
      it 'creates a mapping' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      it 'creates a mapping' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_be_empty
      end
    end
  end

  context 'when a user does not have sufficient permissions' do
    # User is added as a maintainer as all users with roles
    # Maintainer and below are denied the use of this API
    let_it_be(:current_user) { create(:user, maintainer_of: namespace) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when the namespace being passed is a user namespace' do
    let_it_be(:namespace) { current_user.namespace }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include("attempting to access does not exist or " \
                                       "you don't have permission to perform this action")
    end
  end

  context 'when the namespace being passed is a project namespace' do
    let_it_be(:namespace) { agent.project.project_namespace }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include("attempting to access does not exist or " \
                                       "you don't have permission to perform this action")
    end
  end

  context 'when a service error is returned' do
    let(:stub_service_response) { ::ServiceResponse.error(message: 'some error', reason: :bad_request) }

    it_behaves_like 'a mutation that returns errors in the response', errors: ['some error']
  end

  context 'when the required arguments are missing' do
    let(:mutation_args) { all_mutation_args.except(:cluster_agent_id) }

    it 'returns error about required argument' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/provided invalid value for clusterAgentId \(Expected value to not be null\)/)
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(remote_development_namespace_agent_authorization: false)
    end

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/feature flag is disabled/) }
    end
  end

  context "when the cluster agent doesn't exist" do
    let(:agent) { build_stubbed(:cluster_agent) }

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/are attempting to access does not exist/) }
    end
  end

  context "when the group doesn't exist" do
    let(:namespace) { build_stubbed(:group) }

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/are attempting to access does not exist/) }
    end
  end

  context 'when remote_development feature is unlicensed' do
    before do
      stub_licensed_features(remote_development: false)
    end

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/'remote_development' licensed feature is not available/) }
    end
  end
end
