# frozen_string_literal: true

module Search
  module Elastic
    module EpicsSearch
      extend ActiveSupport::Concern

      include ::Elastic::ApplicationVersionedSearch

      included do
        extend ::Gitlab::Utils::Override

        override :maintain_elasticsearch_create
        def maintain_elasticsearch_create
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
        end

        override :maintain_elasticsearch_update
        def maintain_elasticsearch_update(updated_attributes: previous_changes.keys)
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
          associations_to_update = associations_needing_elasticsearch_update(updated_attributes)
          return unless associations_to_update.present?

          ElasticAssociationIndexerWorker.perform_async(self.class.name, id, associations_to_update)
        end

        override :maintain_elasticsearch_destroy
        def maintain_elasticsearch_destroy
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
        end
      end

      private

      def work_item_index_available?
        ::Feature.enabled?(:elastic_index_work_items) && # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Global Feature Flag
          ::Elastic::DataMigrationService.migration_has_finished?(:create_work_items_index)
      end

      def get_indexing_data
        indexing_data = [self]

        # We can remove issue_id check too when we are cleaning the migration completion check
        if work_item_index_available? && issue_id
          indexing_data << Search::Elastic::References::WorkItem.new(issue_id,
            "group_#{group.root_ancestor.id}")
        end

        indexing_data
      end
    end
  end
end
