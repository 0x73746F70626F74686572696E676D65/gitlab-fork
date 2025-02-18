# frozen_string_literal: true

module EE
  module IssuableBaseService
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    private

    override :associations_before_update
    def associations_before_update(issuable)
      associations = super

      associations[:escalation_policy] = issuable.escalation_status&.policy if issuable.escalation_policies_available?
      associations[:approval_rules] = issuable.approval_rules.map(&:hook_attrs) if issuable.supports_approval_rules?

      associations
    end

    attr_reader :label_ids_ordered_by_selection

    override :filter_params
    def filter_params(issuable)
      can_admin_issuable = can_admin_issuable?(issuable)

      unless can_admin_issuable && issuable.weight_available?
        params.delete(:weight)
      end

      unless can_admin_issuable && issuable.supports_health_status?
        params.delete(:health_status)
      end

      [:iteration, :sprint_id].each { |iteration_param| params.delete(iteration_param) } unless can_admin_issuable

      super
    end

    override :filter_labels
    def filter_labels
      super

      @label_ids_ordered_by_selection = params[:add_label_ids].to_a + params[:label_ids].to_a # rubocop:disable Gitlab/ModuleWithInstanceVariables
    end

    def update_task_event?
      strong_memoize(:update_task_event) do
        params.key?(:update_task)
      end
    end

    override :process_label_ids
    def process_label_ids(attributes, issuable:, existing_label_ids: nil, extra_label_ids: [])
      ids = super
      added_label_ids = ids - existing_label_ids.to_a

      filter_mutually_exclusive_labels(ids, added_label_ids, lock_on_merge: issuable.supports_lock_on_merge?)
    end

    def filter_mutually_exclusive_labels(ids, added_label_ids, lock_on_merge: false)
      return ids if added_label_ids.empty? || !container.licensed_feature_available?(:scoped_labels)

      label_sets = ScopedLabelSet.from_label_ids(ids)

      label_sets.flat_map do |set|
        if set.valid? || !set.contains_any?(added_label_ids)
          set.label_ids
        elsif lock_on_merge && set.lock_on_merge_labels?
          set.label_ids - added_label_ids
        else
          set.last_id_by_order(label_ids_ordered_by_selection)
        end
      end
    end

    override :allowed_create_params
    def allowed_create_params(params)
      super(params).except(:epic)
    end

    override :allowed_update_params
    def allowed_update_params(params)
      super(params).except(:epic, :last_test_report_state)
    end
  end
end
