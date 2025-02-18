# frozen_string_literal: true

module EE
  module Resolvers
    module BulkLabelsResolver
      extend ::ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :bulk_load_labels
      def bulk_load_labels
        if object.issuing_parent.is_a?(::Group) && object.issuing_parent.epic_and_work_item_labels_unification_enabled?
          bulk_load_unified_labels
        else
          super
        end
      end

      def bulk_load_unified_labels
        sync_object = object.try(:sync_object)

        batched_object = [
          [object.id, object.class.base_class.name],
          [sync_object&.id, sync_object&.class&.base_class&.name]
        ]

        ::BatchLoader::GraphQL.for(batched_object).batch(key: object.class.name, cache: false) do |ids, loader, _args|
          objects_relation = object.class.id_in(ids.map(&:first).flat_map(&:first))
          sync_objects_relation = sync_object&.class&.id_in(ids.map(&:second).flat_map(&:first))

          labels = unified_labels(objects_relation, sync_objects_relation)

          ids.each do |ids_pair|
            loader.call(ids_pair, [labels[ids_pair[0]], labels[ids_pair[1]]].flatten.compact || [])
          end
        end
      end

      def unified_labels(objects_relation, sync_objects_relation)
        ::Label.from_union(
          [
            ::Label.for_targets(objects_relation),
            ::Label.for_targets(sync_objects_relation)
          ],
          remove_duplicates: true
        ).with_preloaded_container.group_by { |label| [label.target_id, label.target_type] }
      end
    end
  end
end
