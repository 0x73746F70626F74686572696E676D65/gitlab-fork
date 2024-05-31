# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceInitialIndexingWorker
      include ApplicationWorker
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- always otherwise we risk race condition where it doesn't think that indexing is enabled yet for the namespace.
      idempotent!
      pause_control :zoekt
      urgency :low

      DELAY_INTERVAL = 1.hour.freeze

      def perform(zoekt_index_id, options = {})
        return unless ::License.feature_available?(:zoekt_code_search)

        index = Index.find_by_id(zoekt_index_id)
        return unless index

        options = options.with_indifferent_access
        namespace = if options[:namespace_id]
                      Namespace.find_by_id(options[:namespace_id])
                    else
                      index.zoekt_enabled_namespace&.namespace
                    end

        return unless namespace

        namespace.children.each_batch do |relation|
          relation.pluck_primary_key.each do |id|
            self.class.perform_in(rand(DELAY_INTERVAL).seconds, zoekt_index_id, namespace_id: id)
          end
        end

        namespace.projects.each_batch do |relation|
          relation.pluck_primary_key.each { |id| Search::Zoekt.index_in(rand(DELAY_INTERVAL), id) }
        end

        index.in_progress! if index.pending?
      end
    end
  end
end
