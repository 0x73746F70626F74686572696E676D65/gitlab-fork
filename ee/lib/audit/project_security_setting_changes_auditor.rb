# frozen_string_literal: true

module Audit
  class ProjectSecuritySettingChangesAuditor < BaseChangesAuditor
    def initialize(current_user:, model:)
      super(current_user, model)
    end

    def execute
      return if model.blank?

      changed_columns = model.previous_changes.except!(:updated_at)

      changed_columns.each_key do |column|
        audit_change(column)
      end
    end

    private

    def audit_change(column)
      before = model.previous_changes[column].first
      after = model.previous_changes[column].last

      audit_context = {
        name: 'project_security_setting_updated',
        author: @current_user,
        scope: model.project,
        target: model.project,
        message: "Changed #{column} from #{before} to #{after}"
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    def attributes_from_auditable_model(column)
      {
        from: model.previous_changes[column].first,
        to: model.previous_changes[column].last
      }
    end
  end
end
