# frozen_string_literal: true

module Groups
  module Security
    class PoliciesController < Groups::ApplicationController
      include GovernUsageGroupTracking

      before_action :authorize_group_security_policies!, except: :edit
      before_action :authorize_modify_security_policy!, only: :edit
      before_action :validate_policy_configuration, only: :edit

      before_action do
        push_frontend_feature_flag(:compliance_pipeline_in_policies, group)
        push_frontend_feature_flag(:pipeline_execution_policy_type, group)
        push_frontend_feature_flag(:vulnerability_management_policy_type_group, group)
        push_frontend_feature_flag(:scan_execution_policies_with_latest_templates_group, group)
        push_frontend_feature_flag(:approval_policy_disable_bot_comment_group, group)
      end

      feature_category :security_policy_management
      urgency :default, [:edit]
      urgency :low, [:index, :new]
      track_govern_activity 'security_policies', :index, :edit, :new

      def edit
        @policy_name = URI.decode_www_form_component(params[:id])
        @policy = policy

        render_404 if @policy.nil?

        @approvers = approvers
      end

      def index
        render :index, locals: { group: group }
      end

      def schema
        render json: ::Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA_JSON
      end

      private

      def policy_configuration_invalid_component_and_message
        @policy_type = params[:type].presence&.to_sym

        result = ::Security::SecurityOrchestrationPolicies::PolicyConfigurationValidationService.new(
          policy_configuration: policy_configuration,
          type: @policy_type
        ).execute

        [result[:invalid_component], result[:message]] if result[:status] == :error
      end

      def validate_policy_configuration
        invalid_component, error_message = policy_configuration_invalid_component_and_message

        return unless invalid_component

        case invalid_component
        when :policy_project
          redirect_to project_path(policy_configuration.security_policy_management_project), alert: error_message
        when :policy_yaml
          policy_management_project = policy_configuration.security_policy_management_project
          policy_path = File.join(
            policy_management_project.default_branch,
            ::Security::OrchestrationPolicyConfiguration::POLICY_PATH
          )

          redirect_to project_blob_path(policy_management_project, policy_path), alert: error_message
        else
          redirect_to group_security_policies_path(group), alert: error_message
        end
      end

      def group_security_policy_available?
        can?(current_user, :read_security_orchestration_policies, group)
      end

      def authorize_group_security_policies!
        render_404 unless group_security_policy_available?
      end

      def policy
        result = ::Security::SecurityOrchestrationPolicies::FetchPolicyService.new(
          policy_configuration: policy_configuration,
          name: @policy_name,
          type: @policy_type
        ).execute

        result[:policy].presence
      end

      def policy_configuration
        @policy_configuration ||= group.security_orchestration_policy_configuration
      end

      def approvers
        return unless ::Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES.include?(@policy_type)

        result = ::Security::SecurityOrchestrationPolicies::FetchPolicyApproversService.new(
          policy: @policy,
          container: group,
          current_user: @current_user
        ).execute

        return unless result[:status] == :success

        API::Entities::UserBasic.represent(result[:users]) +
          API::Entities::PublicGroupDetails.represent(result[:groups]) +
          result[:roles]
      end
    end
  end
end
