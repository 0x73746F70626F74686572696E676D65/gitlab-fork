# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCheckpointService
      include ::Services::ReturnServiceResponses

      def initialize(project:, workflow:, params:)
        @project = project
        @params = params
        @workflow = workflow
      end

      def execute
        checkpoint = @workflow.checkpoints.new(checkpoint_attributes)

        return error(checkpoint.errors.full_messages, :bad_request) unless checkpoint.save

        success(checkpoint: checkpoint)
      end

      def checkpoint_attributes
        @params.merge(
          workflow: @workflow,
          project: @project
        )
      end
    end
  end
end
