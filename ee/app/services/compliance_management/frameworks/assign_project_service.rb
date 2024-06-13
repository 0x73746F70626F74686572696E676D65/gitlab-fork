# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    class AssignProjectService < BaseService
      def initialize(project, current_user, params)
        @project = project
        @current_user = current_user
        @params = params
      end

      def execute
        return error unless permitted?

        if removing_framework?
          unassign_compliance_framework
        else
          assign_compliance_framework
        end
      end

      private

      attr_reader :project, :current_user, :params

      def permitted?
        can?(current_user, :admin_compliance_framework, project)
      end

      def assign_compliance_framework
        framework = ComplianceManagement::Framework.find_by_id(params[:framework])

        return error unless framework

        ComplianceManagement::ComplianceFramework::ProjectSettings
          .find_or_create_by_project(project, framework)

        publish_event(::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added])

        success
      end

      def unassign_compliance_framework
        project.compliance_framework_settings.each(&:destroy!)

        publish_event(::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed])

        success
      end

      def publish_event(event_type)
        return unless project.compliance_framework_settings.present?

        event = ::Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: project.compliance_framework_settings.first.framework_id,
          event_type: event_type
        })

        ::Gitlab::EventStore.publish(event)
      end

      def removing_framework?
        params[:framework].blank?
      end

      def success
        ServiceResponse.success
      end

      def error
        ServiceResponse.error(message: _('Failed to assign the framework to the project'))
      end
    end
  end
end
