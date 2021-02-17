# frozen_string_literal: true

module IncidentManagement
  module OncallRotations
    class DestroyService < BaseService
      # @param oncall_schedule [IncidentManagement::OncallRotation]
      # @param user [User]
      def initialize(oncall_rotation, user)
        @oncall_rotation = oncall_rotation
        @user = user
        @project = oncall_rotation.project
      end

      def execute
        return error_no_license unless available?
        return error_no_permissions unless allowed?

        if oncall_rotation.destroy
          success(oncall_rotation)
        else
          error(oncall_rotation.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :oncall_rotation, :user, :project

      def error_no_permissions
        error(_('You have insufficient permissions to remove an on-call rotation from this project'))
      end
    end
  end
end
