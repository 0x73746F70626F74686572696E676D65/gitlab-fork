# frozen_string_literal: true

module EE
  module WorkItems
    module ParentLink
      extend ActiveSupport::Concern

      prepended do
        attr_accessor :work_item_syncing
        alias_method :work_item_syncing?, :work_item_syncing
        validate :validate_legacy_hierarchy, unless: :work_item_syncing?

        private

        def validate_legacy_hierarchy
          return unless work_item_parent&.work_item_type&.base_type == 'epic' && work_item&.has_epic?
          return if work_item.epic_issue.epic.issue_id == work_item_parent.id

          errors.add :work_item, _('already assigned to an epic')
        end
      end
    end
  end
end
