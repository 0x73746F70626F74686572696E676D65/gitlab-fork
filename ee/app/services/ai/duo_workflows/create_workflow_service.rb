# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateWorkflowService
      include ::Services::ReturnServiceResponses

      def initialize(project:, current_user:, params:)
        @project = project
        @current_user = current_user
        @params = params
      end

      def execute
        workflow = Ai::DuoWorkflows::Workflow.new(workflow_attributes)

        return error(workflow.errors.full_messages, :bad_request) unless workflow.save

        success(workflow: workflow)
      end

      def workflow_attributes
        @params.merge(
          user: @current_user,
          project: @project
        )
      end
    end
  end
end
