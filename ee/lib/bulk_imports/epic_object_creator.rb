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
        if epic_object.group.epic_sync_to_work_item_enabled?
          # we need to handle epics slightly differently because Epics::CreateService accounts for creating the
          # respective epic work item as well as some other associations.
          epic = ::Epics::CreateService.new(
            group: epic_object.group, current_user: current_user,
            params: epic_work_item_params_from_epic(epic_object)
          ).send(:create, epic_object) # rubocop: disable GitlabSecurity/PublicSend -- using the service to create the epic

          raise(ActiveRecord::RecordInvalid, epic) if epic.invalid?

          epic
        else
          epic_object.save!

          epic_object
        end
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

      def epic_work_item_params_from_epic(epic)
        params = ::Epics::SyncAsWorkItem::ALLOWED_PARAMS.index_with { |attr| epic[attr] }
        # when importing epics we need to make sure we create the work item first but with the epic's IID
        params[:color] = epic.color unless epic.color.to_s == ::Epic::DEFAULT_COLOR.to_s

        params[:start_date] = epic.start_date_fixed
        params[:start_date_is_fixed] = epic.start_date_is_fixed || false
        params[:due_date] = epic.due_date_fixed
        params[:due_date_is_fixed] = epic.due_date_is_fixed || false

        # force the work_item_parent_links record to be created, by forcing the parent related params, that will be
        # handled by Epics::CreateService and EpicLinks::CreateService
        if epic.parent_id || epic.parent
          params[:parent_id] = epic.parent_id
          params[:parent] = epic.parent
        end

        params
      end
    end
  end
end
