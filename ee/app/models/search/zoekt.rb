# frozen_string_literal: true

module Search
  module Zoekt
    EXPIRED_SUBSCRIPTION_GRACE_PERIOD = 30.days

    class << self
      include Gitlab::Utils::StrongMemoize

      def fetch_node_id(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return unless root_namespace_id

        Index.for_root_namespace_id(root_namespace_id).first&.zoekt_node_id
      end

      def search?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        Index.for_root_namespace_id_with_search_enabled(root_namespace_id).ready.exists?
      end

      def index?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        Index.for_root_namespace_id(root_namespace_id).exists?
      end

      def enabled_for_user?(user)
        return false unless ::License.feature_available?(:zoekt_code_search)
        return false unless ::Gitlab::CurrentSettings.zoekt_search_enabled?
        return true unless user # anonymous users have access, the final check is the user's preference setting

        user.enabled_zoekt?
      end

      def index_async(project_id, options = {})
        IndexingTaskWorker.perform_async(project_id, :index_repo) if create_indexing_tasks_enabled?(project_id)

        ::Zoekt::IndexerWorker.perform_async(project_id, options) if Feature.enabled?(:zoekt_legacy_indexer_worker)
      end

      def index_in(delay, project_id, options = {})
        if create_indexing_tasks_enabled?(project_id)
          IndexingTaskWorker.perform_async(project_id, :index_repo, { delay: delay })
        end

        ::Zoekt::IndexerWorker.perform_in(delay, project_id, options) if Feature.enabled?(:zoekt_legacy_indexer_worker)
      end

      def delete_async(project_id, root_namespace_id:, node_id: nil)
        if create_indexing_tasks_enabled?(project_id)
          options = { root_namespace_id: root_namespace_id, node_id: node_id || fetch_node_id(root_namespace_id) }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end

        return unless Feature.enabled?(:zoekt_legacy_indexer_worker)

        DeleteProjectWorker.perform_async(root_namespace_id, project_id, node_id)
      end

      def delete_in(delay, project_id, root_namespace_id:, node_id: nil)
        if create_indexing_tasks_enabled?(project_id)
          options = {
            root_namespace_id: root_namespace_id, node_id: node_id || fetch_node_id(root_namespace_id), delay: delay
          }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end

        return unless Feature.enabled?(:zoekt_legacy_indexer_worker)

        DeleteProjectWorker.perform_in(delay, root_namespace_id, project_id, node_id)
      end

      private

      def create_indexing_tasks_enabled?(project_id)
        Feature.enabled?(:zoekt_create_indexing_tasks, Project.actor_from_id(project_id))
      end

      def fetch_root_namespace_id(container)
        case container
        in Project | Namespace
          container.root_ancestor.id
        in Integer => root_namespace_id
          root_namespace_id
        else
          raise ArgumentError, "#{container.class} class is not supported"
        end
      end
    end
  end
end
