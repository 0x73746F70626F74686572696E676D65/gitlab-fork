# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::ClusterAgentsFinder, feature_category: :remote_development do
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:user) { developer }
  let_it_be(:root_agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, name: "agent-1-root-mapped")
  end

  let_it_be(:root_agent_with_remote_dev_disabled) do
    create(:ee_cluster_agent, project: root_agent.project, name: "agent-2-root-remote-dev-disabled")
  end

  let_it_be(:unmapped_root_agent) do
    create(
      :ee_cluster_agent,
      :with_remote_development_agent_config,
      project: root_agent.project,
      name: "agent-3-root-unmapped"
    )
  end

  let_it_be(:nested_agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, name: "agent-4-nested")
  end

  let_it_be(:migrated_nested_agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, name: "agent-5-nested-migrated")
  end

  let_it_be_with_reload(:root_namespace) do
    create(:group,
      # this project has 3 agents:
      #   1 has remote dev enabled and is mapped to the root namespace
      #   1 has remote dev disabled and is mapped to the root namespace
      #   1 has remote dev disabled and is not mapped to the root namespace
      projects: [root_agent.project],
      children: [
        create(:group,
          projects: [nested_agent.project, migrated_nested_agent.project]
        )
      ]
    )
  end

  let_it_be(:nested_namespace) { root_namespace.children.first }
  let_it_be(:namespace) { root_namespace }
  let(:filter) { :available }

  before_all do
    root_namespace.add_maintainer(maintainer)
    root_namespace.add_developer(developer)

    mappings = [
      [root_agent, root_namespace],
      [root_agent_with_remote_dev_disabled, root_namespace],
      [nested_agent, nested_namespace],
      [migrated_nested_agent, nested_namespace]
    ]

    mappings.each do |mapping|
      agent = mapping[0]
      namespace = mapping[1]

      create(:remote_development_namespace_cluster_agent_mapping, user: user, agent: agent, namespace: namespace)
    end

    # migrate out the project associated with migrated_nested_agent
    migrated_nested_agent.project.update!(group: create(:group))
  end

  subject(:response) do
    described_class.execute(
      namespace: namespace,
      filter: filter,
      user: user
    ).to_a
  end

  context 'with filter_type set to available' do
    context 'when cluster agents are mapped to the namespace' do
      it 'returns cluster agents mapped to the namespace excluding those with remote dev disabled' do
        expect(response).to eq([root_agent])
      end
    end

    context 'when cluster agents are bound to ancestors of the namespace' do
      let(:namespace) { nested_namespace }

      it 'returns cluster agents including those bound to the ancestors' do
        # the returned agents also exclude those that are bound to the namespace but no longer
        # exist within the bound namespace. For ex. nested_namespace is bound to migrated_nested_agent
        # but the project of migrated_nested_agent has been migrated out to a different root namespace
        expect(response).to eq([root_agent, nested_agent])
      end
    end
  end

  context 'with filter_type set to directly_mapped' do
    let(:filter) { :directly_mapped }
    let(:user) { maintainer }

    context 'when some cluster agents are bound to the namespace' do
      let(:namespace) { nested_namespace }

      it 'returns cluster agents that are mapped directly to the namespace' do
        # the returned agents also exclude those that are bound to the namespace but no longer
        # exist within the bound namespace. For ex. nested_namespace is bound to migrated_nested_agent
        # but the project of migrated_nested_agent has been migrated out to a different root namespace
        expect(response).to eq([nested_agent])
      end
    end

    context 'when some mapped cluster agents have remote development disabled' do
      it 'return mapped cluster agents including those with remote development disabled' do
        expect(response).to eq([root_agent, root_agent_with_remote_dev_disabled])
      end
    end

    context 'when no cluster agents are bound to the namespace' do
      let(:namespace) { create(:group).tap { |ns| ns.add_maintainer(user) } }

      it 'returns no cluster agents' do
        expect(response).to eq([])
      end
    end

    context 'when user does not have adequate permissions' do
      let(:user) { developer }

      it 'raises an AccessDeniedError' do
        expect { response }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end
  end

  context 'with filter_type set to unmapped' do
    let(:filter) { :unmapped }
    let_it_be(:user) { maintainer }

    context 'when cluster agents exist within a namespace that are not yet bound to it' do
      it 'returns cluster agents within the namespace not yet bound to the namespace' do
        expect(response).to eq([unmapped_root_agent, nested_agent])
      end
    end

    context 'when all cluster agents within the namespace are bound to it' do
      let(:namespace) { nested_namespace }

      it 'returns an empty result' do
        expect(response).to eq([])
      end
    end

    context 'when user does not have adequate permissions' do
      let(:user) { developer }

      it 'raises an AccessDeniedError' do
        expect { response }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end
  end

  context 'with an invalid value for filter_type' do
    let(:filter) { "some_invalid_value" }

    it 'raises a RuntimeError' do
      expect { response }.to raise_error(RuntimeError, "Unsupported value for filter: #{filter}")
    end
  end
end
