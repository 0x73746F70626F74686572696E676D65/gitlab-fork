# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappings::Delete::MappingDeleter, feature_category: :remote_development do
  include ResultMatchers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:agent) { create(:cluster_agent) }
  let(:context) { { namespace: namespace, cluster_agent: agent } }

  subject(:result) do
    described_class.delete(context)
  end

  context 'when mapping does not exist for given cluster agent and namespace' do
    it 'returns an err Result indicating that a mapping does not exist' do
      expect(result).to be_err_result(RemoteDevelopment::Messages::NamespaceClusterAgentMappingNotFound.new)
    end
  end

  context 'when mapping exists for given cluster agent and namespace' do
    let(:creator) { create(:user) }

    before do
      RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping.new(
        namespace_id: namespace.id,
        cluster_agent_id: agent.id,
        creator_id: creator.id
      ).save!
    end

    it 'returns an ok Result indicating that the mapping has been deleted' do
      expect(result).to be_ok_result(RemoteDevelopment::Messages::NamespaceClusterAgentMappingDeleteSuccessful.new({}))
    end
  end
end
