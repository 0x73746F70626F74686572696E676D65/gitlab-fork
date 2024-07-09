# frozen_string_literal: true

# See https://docs.gitlab.com/ee/development/database/batched_background_migrations.html
# for more information on how to use batched background migrations

# Update below commented lines with appropriate values.

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillRootNamespaceClusterAgentMappings
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_root_namespace_cluster_agent_mappings
          scope_to ->(relation) { relation.where(enabled: true) }
        end

        module LogUtils
          MIGRATOR = 'BackfillRootNamespaceClusterAgentMappings'

          def log_info(log_attributes)
            ::Gitlab::BackgroundMigration::Logger.info(log_attributes.merge(migrator: MIGRATOR))
          end
        end

        class Project < ::ApplicationRecord
          self.table_name = 'projects'
        end

        class Namespace < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled
        end

        class ClusterAgent < ::ApplicationRecord
          self.table_name = 'cluster_agents'
        end

        class RemoteDevelopmentNamespaceClusterAgentMapping < ::ApplicationRecord
          extend LogUtils

          self.table_name = 'remote_development_namespace_cluster_agent_mappings'

          INSERT_SQL = <<~SQL.squish
            INSERT INTO remote_development_namespace_cluster_agent_mappings
              (namespace_id, cluster_agent_id, creator_id, created_at, updated_at)
              VALUES
              %{insert_tuples}
            ON CONFLICT (namespace_id, cluster_agent_id) DO NOTHING;
          SQL
          class << self
            def insert_namespace_cluster_agent_mappings(mappings)
              return log_info(message: 'No mappings to create') unless mappings.present?

              tuples = mappings.map do |mapping|
                format(
                  "(%{namespace_id}, %{cluster_agent_id}, %{creator_id}, NOW(), NOW())",
                  namespace_id: mapping[:namespace_id],
                  cluster_agent_id: mapping[:cluster_agent_id],
                  creator_id: migration_user.id
                )
              end

              run_insert(tuples)
            end

            private

            def run_insert(tuples)
              insert_sql = format(INSERT_SQL, insert_tuples: tuples.join(', '))

              connection.execute(insert_sql)
              log_info(message: 'Insert query has been executed')
            end

            def migration_user
              ::Users::Internal.migration_bot
            end
          end
        end

        include LogUtils

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            ids = sub_batch.map(&:id)
            log_info(message: 'Migration started for batch', start_id: ids.min, end_id: ids.max)

            relevant_agent_ids = sub_batch.map(&:cluster_agent_id)
            root_group_by_agent_id = root_groups_for_cluster_agents(cluster_agent_ids: relevant_agent_ids)

            mappings = root_group_by_agent_id.map do |cluster_agent_id, root_group_id|
              {
                namespace_id: root_group_id,
                cluster_agent_id: cluster_agent_id
              }
            end

            RemoteDevelopmentNamespaceClusterAgentMapping.insert_namespace_cluster_agent_mappings(mappings)
            log_info(message: 'Migration ended for batch', start_id: ids.min, end_id: ids.max)
          end
        end

        def root_groups_for_cluster_agents(cluster_agent_ids:)
          agents_by_id = ClusterAgent.id_in(cluster_agent_ids).index_by(&:id)

          projects_by_id = Project.id_in(agents_by_id.values.map(&:project_id)).index_by(&:id)

          project_namespaces_by_id =
            Namespace.id_in(projects_by_id.values.map(&:project_namespace_id)).index_by(&:id)

          root_group_namespaces_by_id =
            Namespace
              .id_in(
                project_namespaces_by_id.values.map(&:traversal_ids)[0] # pluck the root namespace from traversal ids
              )
              .where(type: 'Group')
              .index_by(&:id)

          cluster_agent_ids.each_with_object({}) do |cluster_agent_id, hash|
            next unless agents_by_id.has_key?(cluster_agent_id)

            agent = agents_by_id[cluster_agent_id]

            # projects_by_id must contain agent.project_id as "agents" table has a ON CASCADE DELETE constraint with
            # respect to the "projects" table. As such, if an agent can be retrieved from the database,
            # so should its project
            project = projects_by_id[agent.project_id]

            # project_namespaces_by_id must contain project.project_namespace_id as "projects" table has a
            # ON CASCADE DELETE constraint with respect to the projects table. As such, if a project can be retrieved
            # from the database, so should its project_namespace
            project_namespace = project_namespaces_by_id[project.project_namespace_id]

            root_namespace_id = project_namespace.traversal_ids.first

            hash[cluster_agent_id] = root_namespace_id if root_group_namespaces_by_id.has_key?(root_namespace_id)
          end
        end
      end
    end
  end
end
