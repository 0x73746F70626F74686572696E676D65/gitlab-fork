# frozen_string_literal: true

module Ci
  module PipelineTriggers
    class CreateService
      include Gitlab::Allowable

      attr_reader :project, :current_user, :description

      def initialize(project:, user:, description:)
        @project = project
        @current_user = user
        @description = description
      end

      def execute
        unless can?(current_user, :manage_trigger, project)
          return ServiceResponse.error(
            message: _('The current user is not authorized to create a pipeline trigger token'),
            payload: { trigger: nil },
            reason: :forbidden
          )
        end

        trigger = project.triggers.create(**create_params)

        if trigger.present? && trigger.persisted?
          ServiceResponse.success(payload: { trigger: trigger })
        elsif trigger.present? && trigger.errors.any?
          ServiceResponse.error(
            message: trigger.errors.to_json,
            payload: { trigger: trigger },
            reason: :validation_error
          )
        else
          raise "Unexpected Ci::Trigger creation failure. Description: #{@description}"
        end
      end

      private

      def create_params
        { description: description, owner: current_user }
      end
    end
  end
end
