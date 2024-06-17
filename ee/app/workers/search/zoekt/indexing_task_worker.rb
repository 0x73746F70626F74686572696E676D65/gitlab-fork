# frozen_string_literal: true

module Search
  module Zoekt
    class IndexingTaskWorker
      include ApplicationWorker
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      data_consistency :delayed
      idempotent!
      pause_control :zoekt
      urgency :low

      def perform(project_id, task_type, options = {})
        return unless ::License.feature_available?(:zoekt_code_search)

        options = options.with_indifferent_access
        keyword_args = {
          node_id: options[:node_id], force: options[:force], delay: options[:delay],
          root_namespace_id: options[:root_namespace_id]
        }.compact
        IndexingTaskService.execute(project_id, task_type, **keyword_args)
      end
    end
  end
end
