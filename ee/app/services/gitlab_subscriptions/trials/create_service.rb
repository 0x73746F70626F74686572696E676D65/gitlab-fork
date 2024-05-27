# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateService < BaseCreateService
      NAMESPACE_CREATE_FAILED = :namespace_create_failed

      private

      def trial_flow
        # The value of 0 is the option in the select for creating a new group
        create_new_group_selected = trial_params[:namespace_id] == '0'

        if trial_params[:namespace_id].present? && !create_new_group_selected
          existing_namespace_flow
        elsif trial_params.key?(:new_group_name)
          create_group_flow
        else
          not_found
        end
      end

      def create_group_flow
        # Instance admins can disable user's ability to create top level groups.
        # See https://docs.gitlab.com/ee/administration/admin_area.html#prevent-a-user-from-creating-groups
        return not_found unless user.can_create_group?

        name = ActionController::Base.helpers.sanitize(trial_params[:new_group_name])
        path = Namespace.clean_path(name.parameterize)
        create_service_params = { name: name, path: path, organization_id: trial_params[:organization_id] }
        response = Groups::CreateService.new(user, create_service_params).execute
        @namespace = response[:group]

        if response.success?
          apply_trial_flow
        else
          ServiceResponse.error(
            message: namespace.errors.full_messages,
            payload: { namespace_id: trial_params[:namespace_id] },
            reason: NAMESPACE_CREATE_FAILED
          )
        end
      end

      def lead_service_class
        GitlabSubscriptions::CreateLeadService
      end

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyTrialService
      end

      def namespaces_eligible_for_trial
        user.manageable_namespaces_eligible_for_trial
      end
    end
  end
end
