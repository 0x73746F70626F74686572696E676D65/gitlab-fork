# frozen_string_literal: true

module EE
  module WorkItem
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include FilterableByTestReports

      # we'd need to make sure these override the existing associations so we prepend this.
      include ::WorkItems::EpicAsWorkItem

      has_one :sync_object, class_name: 'Epic', foreign_key: 'issue_id', inverse_of: :sync_object
      has_one :progress, class_name: 'WorkItems::Progress', foreign_key: 'issue_id', inverse_of: :work_item
      has_one :color, class_name: 'WorkItems::Color', foreign_key: 'issue_id', inverse_of: :work_item

      delegate :reminder_frequency, to: :progress, allow_nil: true

      scope :with_reminder_frequency, ->(frequency) {
                                        joins(:progress).where(work_item_progresses: { reminder_frequency: frequency })
                                      }
      scope :without_parent, -> {
                               where("NOT EXISTS (SELECT FROM work_item_parent_links WHERE work_item_id = issues.id)")
                             }
      scope :with_assignees, -> { joins(:issue_assignees).includes(:assignees) }
      scope :with_descendents_of, ->(ids) {
                                    joins(:work_item_parent).where(work_item_parent_links: { work_item_parent_id: ids })
                                  }
      scope :with_previous_reminder_sent_before, ->(datetime) do
        left_joins(:progress).where(
          "work_item_progresses.last_reminder_sent_at IS NULL
          OR work_item_progresses.last_reminder_sent_at <= ?",
          datetime
        )
      end
      scope :grouped_by_work_item, -> { group(:id) }
      scope :preload_for_indexing, -> { includes(:namespace, :sync_object, project: :project_feature) }
    end

    class_methods do
      def with_api_entity_associations
        super.preload(:sync_object)
      end
    end

    def widgets
      strong_memoize(:widgets) do
        work_item_type.widgets(resource_parent).map do |widget_class|
          widget_class.new(self)
        end
      end
    end

    def average_progress_of_children
      children = work_item_children
      child_count = children.count
      return 0 unless child_count > 0

      (::WorkItems::Progress.where(work_item: children).sum(:progress).to_i / child_count).to_i
    end

    override :skip_metrics?
    def skip_metrics?
      super || epic_work_item?
    end

    override :use_elasticsearch?
    def use_elasticsearch?
      elasticsearch_available = ::Feature.enabled?(:elastic_index_work_items) && # rubocop:disable Gitlab/FeatureFlagWithoutActor -- We do not need an actor here
        ::Elastic::DataMigrationService.migration_has_finished?(:create_work_items_index)
      return super unless elasticsearch_available

      namespace.use_elasticsearch?
    end

    def epic_work_item?
      work_item_type.epic?
    end

    def es_parent
      "group_#{namespace.root_ancestor.id}"
    end

    def elastic_reference
      ::Search::Elastic::References::WorkItem.serialize(self)
    end

    private

    override :linked_work_items_query
    def linked_work_items_query(link_type)
      case link_type
      when ::WorkItems::RelatedWorkItemLink::TYPE_BLOCKS
        blocking_work_items_query
      when ::WorkItems::RelatedWorkItemLink::TYPE_IS_BLOCKED_BY
        blocking_work_items_query(inverse_direction: true)
      else
        super
      end
    end

    def blocking_work_items_query(inverse_direction: false)
      link_class = ::WorkItems::RelatedWorkItemLink
      columns = %w[target_id source_id]
      columns.reverse! if inverse_direction

      linked_issues_select
        .joins("INNER JOIN issue_links ON issue_links.#{columns[0]} = issues.id")
        .where(issue_links: { columns[1] => id, link_type: link_class.link_types[link_class::TYPE_BLOCKS] })
    end

    override :allowed_work_item_type_change
    def allowed_work_item_type_change
      super

      return unless previous_type_was_epic?
      return unless synced_epic.present?

      errors.add(
        :work_item_type_id,
        format(
          _('cannot be changed to %{new_type} when the work item is a legacy epic synced work item'),
          new_type: work_item_type.name.downcase
        )
      )
    end

    def previous_type_was_epic?
      changes["work_item_type_id"].first == ::WorkItems::Type.default_by_type(:epic).id
    end
  end
end
