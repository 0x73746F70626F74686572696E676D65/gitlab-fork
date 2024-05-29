# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.namespace.remote_development_cluster_agents(filter: DIRECTLY_MAPPED)',
  feature_category: :remote_development do
  include GraphqlHelpers
  include StubFeatureFlags

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user }
  # Setup cluster and user such that the user has the bare minimum permissions
  # to be able to retrieve directly mapped agent when calling the API i.e.
  # the user has Maintainer access for the group
  let_it_be(:mapped_agent) do
    create(:ee_cluster_agent, :in_group, :with_remote_development_agent_config).tap do |agent|
      agent.project.namespace.add_maintainer(user)
    end
  end

  let_it_be(:unmapped_agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, project: mapped_agent.project)
  end

  let_it_be(:namespace) { mapped_agent.project.namespace }
  let_it_be(:namespace_agent_mapping) do
    create(
      :remote_development_namespace_cluster_agent_mapping,
      user: user,
      agent: mapped_agent,
      namespace: namespace
    )
  end

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('cluster_agents'.classify, max_depth: 1)}
      }
    QUERY
  end

  let(:agent_names_in_response) { subject.pluck('name') }
  let(:query) do
    graphql_query_for(
      :namespace,
      { full_path: namespace.full_path },
      query_graphql_field(
        :remote_development_cluster_agents,
        { filter: :DIRECTLY_MAPPED },
        fields
      )
    )
  end

  subject { graphql_data.dig('namespace', 'remoteDevelopmentClusterAgents', 'nodes') }

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'when the params are valid' do
    it 'returns cluster agents that are directly mapped to the namespace' do
      post_graphql(query, current_user: current_user)

      expect(agent_names_in_response).to eq([mapped_agent.name])
    end
  end

  context 'when the passed namespace is not a group' do
    let(:namespace) { mapped_agent.project.project_namespace }

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect_graphql_errors_to_include "does not exist or you don't have permission to perform this action"
    end
  end

  include_examples "checks for remote_development licensed feature"
  include_examples "checks whether the feature flag is enabled"

  context 'when user does not have access to view the mappings' do
    # simulate test conditions by creating the maximum privileged user that does/should
    # not have the permission to access the agent
    let(:current_user) do
      create(:user).tap do |user|
        namespace.add_developer(user)
      end
    end

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect_graphql_errors_to_include "does not exist or you don't have permission to perform this action"
    end
  end
end
