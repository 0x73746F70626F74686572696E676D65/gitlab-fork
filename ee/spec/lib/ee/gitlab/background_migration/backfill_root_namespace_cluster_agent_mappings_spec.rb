# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillRootNamespaceClusterAgentMappings, :migration,
  feature_category: :remote_development do
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:cluster_agents) { table(:cluster_agents) }
  let(:rd_agent_configs) { table(:remote_development_agent_configs) }
  let(:rd_namespace_cluster_agent_mappings) { table(:remote_development_namespace_cluster_agent_mappings) }

  let!(:namespace) do
    namespaces.create!(name: 'root-group', path: 'root', type: 'Group').tap do |new_group|
      new_group.update!(traversal_ids: [new_group.id])
    end
  end

  let!(:nested_group) do
    namespaces.create!(name: 'nested-group', path: 'root/nested_group', type: 'Group').tap do |new_group|
      new_group.update!(traversal_ids: [namespace.id, new_group.id])
    end
  end

  let!(:project) do
    projects.create!(
      namespace_id: nested_group.id,
      project_namespace_id: nested_group.id,
      name: 'agent project',
      path: 'agent-project'
    )
  end

  let!(:agent) do
    cluster_agents.create!(
      name: 'agent with remote dev enabled',
      project_id: project.id
    )
  end

  let!(:rd_agent_config) do
    rd_agent_configs.create!(
      cluster_agent_id: agent.id,
      enabled: true,
      dns_zone: "www.example.com"
    )
  end

  let(:all_rd_agent_configs) { [rd_agent_config] }
  let(:migration_attrs) do
    {
      start_id: all_rd_agent_configs.minimum(:id),
      end_id: all_rd_agent_configs.maximum(:id),
      batch_table: :remote_development_agent_configs,
      batch_column: :id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let(:migration) { described_class.new(**migration_attrs) }

  describe '#perform' do
    shared_examples "skipped migration" do
      it 'skips migration for such records' do
        migration.perform

        expect(
          rd_namespace_cluster_agent_mappings
            .where(namespace_id: namespace.id, cluster_agent_id: agent.id)
            .count
        ).to eq(0)
      end
    end

    context 'when remote dev is enabled for an agent project that resides within a group' do
      it 'create a mapping from the cluster agent to its root namespace' do
        migration.perform

        migrated_records = rd_namespace_cluster_agent_mappings
          .where(namespace_id: namespace.id, cluster_agent_id: agent.id)
        expect(migrated_records.count).to eq(1)
        expect(migrated_records.first.creator_id).to eq(::Users::Internal.migration_bot.id)
      end
    end

    context 'when rd-enabled cluster agent project resides within a user namespace' do
      let!(:namespace) do
        namespaces.create!(name: 'user-namespace', path: 'user-namespace', type: 'User').tap do |new_namespace|
          new_namespace.update!(traversal_ids: [new_namespace.id])
        end
      end

      it_behaves_like "skipped migration"
    end

    context 'when remote dev is disabled for an agent within a group' do
      let!(:rd_agent_config) do
        rd_agent_configs.create!(
          cluster_agent_id: agent.id,
          enabled: false,
          dns_zone: "www.example.com"
        )
      end

      it_behaves_like "skipped migration"
    end

    context 'when mapping already exists between an agent and the root namespace' do
      let!(:existing_mapping) do
        rd_namespace_cluster_agent_mappings.create!(
          cluster_agent_id: agent.id,
          namespace_id: namespace.id,
          creator_id: ::Users::Internal.admin_bot.id
        )
      end

      it 'skips migration for such records' do
        migration.perform

        mappings = rd_namespace_cluster_agent_mappings.where(namespace_id: namespace.id, cluster_agent_id: agent.id)
        expect(mappings.count).to eq(1)
        expect(mappings.first.creator_id).to eq(::Users::Internal.admin_bot.id)
        expect(mappings.first.created_at).to be_within(0.00001.seconds).of(existing_mapping.created_at)
        expect(mappings.first.updated_at).to be_within(0.00001.seconds).of(existing_mapping.updated_at)
      end
    end
  end
end
