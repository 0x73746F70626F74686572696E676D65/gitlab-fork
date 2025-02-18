# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    class ExportService
      TARGET_FILESIZE = 15.megabytes

      def initialize(user:, group:)
        @user = user
        @group = group
      end

      def execute
        return ServiceResponse.error(message: 'namespace must be a group') unless group.is_a?(Group)
        return ServiceResponse.error(message: "Access to group denied for user with ID: #{user.id}") unless allowed?

        ServiceResponse.success(payload: csv_builder.render(TARGET_FILESIZE))
      end

      def email_export
        FrameworkExportMailerWorker.perform_async(user.id, group.id)

        ServiceResponse.success
      end

      private

      attr_reader :user, :group

      def csv_builder
        @csv_builder ||= CsvBuilder.new(rows, csv_header)
      end

      def allowed?
        Ability.allowed?(user, :read_group_compliance_dashboard, group)
      end

      def rows
        group.compliance_management_frameworks
      end

      def csv_header
        {
          'Name' => 'name',
          'Associated Projects' => ->(framework) { framework.projects.map(&:name).join(', ') }
        }
      end
    end
  end
end
