# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectSettings < ApplicationRecord
      self.table_name = 'project_compliance_framework_settings'
      self.primary_key = :project_id

      belongs_to :project
      belongs_to :compliance_management_framework, class_name: "ComplianceManagement::Framework", foreign_key: :framework_id

      validates :project, presence: true

      delegate :full_path, to: :project

      def self.find_or_create_by_project(project, framework)
        find_or_initialize_by(project: project).tap do |setting|
          setting.framework_id = framework.id
          setting.save
        end
      end
    end
  end
end
