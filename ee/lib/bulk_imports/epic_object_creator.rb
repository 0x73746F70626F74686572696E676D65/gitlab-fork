# frozen_string_literal: true

module BulkImports
  module EpicObjectCreator
    extend ActiveSupport::Concern

    included do
      def save_relation_object(relation_object, relation_key, relation_definition, relation_index)
        return super unless %w[epics epic issues issue].include?(relation_key)

        if %w[issues issue].include?(relation_key)
          super # create the issue first
          return handle_epic_issue(relation_object)
        end

        create_epic(relation_object) if relation_object.new_record?
      end

      def persist_relation(attributes)
        relation_object = super(**attributes)

        return relation_object if !relation_object || !relation_object.is_a?(::Epic) || relation_object.persisted?

        create_epic(relation_object)
      end

      private

      def create_epic(epic_object)
        # we need to handle epics slightly differently because Epics::CreateService accounts for creating the
        # respective epic work item as well as some other associations.
        epic = ::Epics::CreateService.new(
          group: epic_object.group, current_user: current_user, params: {}
        ).send(:create, epic_object) # rubocop: disable GitlabSecurity/PublicSend -- using the service to create the epic

        raise(ActiveRecord::RecordInvalid, epic) if epic.invalid?

        handle_parent_link(epic)

        epic
      end

      def handle_parent_link(epic)
        # We need to create WorkItems::ParentLinks as we don't create them in the service since we don't pass
        # the `parent_id`.
        # This is especially important when the source and target group are on different licenses.
        # e.g. A group with sub-epics exports to a group without sub-epics.
        # We still want to retain the relationships.
        return unless epic.issue_id
        return unless epic.parent_id && epic.parent.issue_id

        existing_parent_link = epic.work_item&.parent_link
        return if existing_parent_link.present?

        ::WorkItems::ParentLinks::CreateService.new(
          epic.parent.work_item, current_user,
          { target_issuable: epic.work_item, synced_work_item: true, relative_position: epic.relative_position }
        ).execute
      end

      def handle_epic_issue(relation_object)
        issue_as_work_item = WorkItem.id_in(relation_object.id).first

        if issue_as_work_item.epic && issue_as_work_item.epic.work_item
          work_item_parent_link = issue_as_work_item.epic.work_item.child_links.for_children(issue_as_work_item)

          unless work_item_parent_link.present?
            ::WorkItems::ParentLinks::CreateService.new(
              issue_as_work_item.epic.work_item, current_user,
              { target_issuable: issue_as_work_item, synced_work_item: true }
            ).execute
          end
        end

        relation_object
      end
    end
  end
end
