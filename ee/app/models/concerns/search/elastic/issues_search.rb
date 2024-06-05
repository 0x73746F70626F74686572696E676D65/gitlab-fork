# frozen_string_literal: true

module Search
  module Elastic
    module IssuesSearch
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
          super unless indexing_issue_of_epic_type?
        end

        override :maintain_elasticsearch_destroy
        def maintain_elasticsearch_destroy
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
        end
      end

      private

      def indexing_issue_of_epic_type?
        project.nil?
      end

      def work_item_index_available?
        ::Feature.enabled?(:elastic_index_work_items) && # rubocop:disable Gitlab/FeatureFlagWithoutActor -- We do not need an actor here
          ::Elastic::DataMigrationService.migration_has_finished?(:create_work_items_index)
      end

      def get_indexing_data
        indexing_data = []
        case self
        when WorkItem
          indexing_data << self if work_item_index_available?

          unless indexing_issue_of_epic_type?
            indexing_data << Search::Elastic::References::Legacy.instantiate_from_array([Issue, id, es_id,
              "project_#{project.id}"])
          end
        when Issue
          if work_item_index_available?
            indexing_data << Search::Elastic::References::WorkItem.new(id, "group_#{namespace.root_ancestor.id}")
          end

          indexing_data << self unless indexing_issue_of_epic_type?
        end
        indexing_data.compact
      end
    end
  end
end
