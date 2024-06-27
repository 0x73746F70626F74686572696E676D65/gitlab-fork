# frozen_string_literal: true

module EE
  module IssuePolicy
    extend ActiveSupport::Concern

    class_methods do
      def synced_work_item_disallowed_abilities
        ::IssuePolicy.ability_map.map.keys.select { |ability| !ability.to_s.starts_with?("read_") }
      end
    end

    prepended do
      with_scope :subject
      condition(:summarize_notes_enabled) do
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject_container,
          feature_name: :summarize_comments
        ).allowed?
      end

      condition(:relations_for_non_members_available) do
        scope = group_issue? ? subject_container : subject_container.group

        ::Feature.enabled?(:epic_relations_for_non_members, scope)
      end

      condition(:member_or_support_bot) do
        (is_project_member? && can?(:read_issue)) || (support_bot? && service_desk_enabled?)
      end

      condition(:can_edit_synced_epic_work_item, scope: :subject) do
        next true unless @subject.work_item_type&.epic?
        next true unless @subject.sync_object.present?

        scope = group_issue? ? subject_container : subject_container.group

        ::Feature.enabled?(:synced_epic_work_item_editable, scope, type: :wip)
      end

      rule { can_be_promoted_to_epic }.policy do
        enable :promote_to_epic
      end

      rule do
        summarize_notes_enabled & can?(:read_issue)
      end.enable :summarize_comments

      rule { relations_for_non_members_available & ~member_or_support_bot }.policy do
        prevent :admin_issue_relation
      end

      rule { ~can_edit_synced_epic_work_item }.policy do
        prevent(*synced_work_item_disallowed_abilities)
      end
    end
  end
end
