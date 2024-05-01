# frozen_string_literal: true

module Search
  module Zoekt
    EXPIRED_SUBSCRIPTION_GRACE_PERIOD = 30.days

    class << self
      def fetch_node_id(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return unless root_namespace_id

        ::Search::Zoekt::Index.for_root_namespace_id(root_namespace_id).first&.zoekt_node_id
      end

      def search?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        ::Search::Zoekt::Index.for_root_namespace_id_with_search_enabled(root_namespace_id).ready.exists?
      end

      def index?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        ::Search::Zoekt::Index.for_root_namespace_id(root_namespace_id).exists?
      end

      def enabled_for_user?(user)
        return false unless ::Feature.enabled?(:search_code_with_zoekt, user)
        return false unless ::License.feature_available?(:zoekt_code_search)
        return true unless user # anonymous users have access, the final check is the user's preference setting

        user.enabled_zoekt?
      end

      def index_async(project_id, options = {})
        return unless Feature.enabled?(:zoekt_legacy_indexer_worker)

        ::Zoekt::IndexerWorker.perform_async(project_id,
          options)
      end

      def index_in(delay, project_id, options = {})
        return unless Feature.enabled?(:zoekt_legacy_indexer_worker)

        ::Zoekt::IndexerWorker.perform_in(delay, project_id,
          options)
      end

      def delete_async(project_id, root_namespace_id:, node_id: nil)
        return if Feature.disabled?(:zoekt_legacy_indexer_worker)

        ::Search::Zoekt::DeleteProjectWorker.perform_async(root_namespace_id, project_id, node_id)
      end

      def delete_in(delay, project_id, root_namespace_id:, node_id: nil)
        return if Feature.disabled?(:zoekt_legacy_indexer_worker)

        ::Search::Zoekt::DeleteProjectWorker.perform_in(delay, root_namespace_id, project_id, node_id)
      end

      private

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
