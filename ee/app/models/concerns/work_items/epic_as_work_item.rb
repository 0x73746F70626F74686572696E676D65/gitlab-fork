# frozen_string_literal: true

module WorkItems
  module EpicAsWorkItem
    extend ActiveSupport::Concern

    included do
      include Gitlab::Utils::StrongMemoize
      include ::WorkItems::UnifiedAssociations::Labels
      include ::WorkItems::UnifiedAssociations::AwardEmoji
      include ::WorkItems::UnifiedAssociations::DescriptionVersions

      # this overrides the scope in Issuable by removing the labels association from it as labels are now preloaded
      # by loading labels for epic and for epic work item
      scope :includes_for_bulk_update, -> do
        association_symbols = %i[author sync_object assignees epic group metrics project source_project target_project]
        associations = association_symbols.select do |assoc|
          reflect_on_association(assoc)
        end

        includes(*associations)
      end

      def container
        case resource_parent
        when Group
          resource_parent
        when Project
          resource_parent.group
        end
      end
      strong_memoize_attr :container

      def unified_associations?
        container&.epic_and_work_item_associations_unification_enabled? && try(:sync_object)
      end

      def labels_unification_enabled?
        unified_associations? && container&.epic_and_work_item_labels_unification_enabled?
      end

      def notes_unification_enabled?
        unified_associations? && container&.epic_and_work_item_notes_unification_enabled?
      end
    end
  end
end
