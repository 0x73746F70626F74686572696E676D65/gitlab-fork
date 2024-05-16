# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceIndexerWorker
      include ApplicationWorker
      prepend ::Geo::SkipSecondary

      INDEXING_DELAY_PER_PROJECT = 10.seconds

      # Must be always otherwise we risk race condition where it does not think that indexing is enabled yet for the
      # namespace.
      data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency
      feature_category :global_search
      idempotent!
      pause_control :zoekt

      def perform(namespace_id, operation, node_id = nil)
        return unless ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

        namespace = Namespace.find(namespace_id)

        # Symbols convert to string when queuing in Sidekiq
        case operation.to_sym
        when :index
          index_projects(namespace)
        when :delete
          remove_projects(namespace, node_id: node_id)
        end
      end

      private

      def index_projects(namespace)
        return unless namespace.use_zoekt?

        delay = 0
        namespace.all_projects.find_each do |project|
          ::Search::Zoekt.index_in(delay, project.id)

          delay += INDEXING_DELAY_PER_PROJECT
        end
      end

      def remove_projects(namespace, node_id:)
        namespace.all_projects.find_each do |project|
          ::Search::Zoekt.delete_async(project.id, root_namespace_id: project.root_namespace&.id, node_id: node_id)
        end
      end
    end
  end
end
