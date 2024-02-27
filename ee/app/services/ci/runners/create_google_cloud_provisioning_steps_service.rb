# frozen_string_literal: true

module Ci
  module Runners
    # Creates the scripts required to provision a runner in a Google Cloud project
    #
    class CreateGoogleCloudProvisioningStepsService < BaseProjectService
      # From https://gitlab.com/gitlab-org/ci-cd/runner-tools/grit/-/blob/4607443d96f808af8dd049acea455b6e26e67991/modules/internal/validation/name/name.tf
      DEPLOYMENT_NAME_MAX_LENGTH = 20
      DEPLOYMENT_NAME_REGEXP = /^[0-9A-Za-z_-]+$/
      TEMPLATES_LOCATION = %w[ee lib api templates ci].freeze
      TERRAFORM_TEMPLATE_PATH = File.join(*TEMPLATES_LOCATION, 'google_cloud_integration_grit_provisioning.tf.erb')
      SHELL_TEMPLATE_PATH = File.join(*TEMPLATES_LOCATION, 'google_cloud_integration_grit_provisioning.sh.erb')

      def execute
        validation_error = validate
        return validation_error if validation_error

        ServiceResponse.success(payload: {
          provisioning_steps: [
            {
              title: 'Save the Terraform script to a file',
              language_identifier: 'terraform',
              instructions: instructions[:terraform_script]
            },
            {
              title: 'Apply the Terraform script',
              language_identifier: 'shell',
              instructions: instructions[:shell_script]
            }
          ]
        })
      end

      private

      def validate
        if Feature.disabled?(:google_cloud_runner_provisioning, project)
          return ServiceResponse.error(
            message: s_('Runners|Google Cloud provisioning is disabled for this project'),
            reason: :google_cloud_provisioning_disabled
          )
        end

        unless Ability.allowed?(current_user, :provision_cloud_runner, project)
          return ServiceResponse.error(
            message: s_('Runners|The user is not allowed to provision a cloud runner'),
            reason: :insufficient_permissions
          )
        end

        if runner_token.present? && runner.nil?
          return ServiceResponse.error(
            message: s_('Runners|The runner authentication token is invalid'),
            reason: :invalid_argument
          )
        end

        if runner.nil? && !Ability.allowed?(current_user, :create_runner, project)
          return ServiceResponse.error(
            message: s_('Runners|The user is not allowed to create a runner'),
            reason: :insufficient_permissions
          )
        end

        return if deployment_name.match?(DEPLOYMENT_NAME_REGEXP)

        ServiceResponse.error(
          message: s_('Runners|The deployment name is invalid'),
          reason: :internal_error
        )
      end

      def deployment_name
        # Unique in context of Google Cloud project, no longer than 12 characters
        unique_id = runner&.short_sha || Devise.friendly_token(8)
        "grit#{unique_id}"[0..DEPLOYMENT_NAME_MAX_LENGTH - 1]
      end
      strong_memoize_attr :deployment_name

      def runner
        return unless runner_token.present?

        ::Ci::Runner.find_by_token(runner_token)
      end
      strong_memoize_attr :runner

      def instructions
        terraform_template = ERB.new(File.read(TERRAFORM_TEMPLATE_PATH))
        shell_template = ERB.new(File.read(SHELL_TEMPLATE_PATH))

        locals = {
          runner_token: runner_token,
          provisioning_project_id: provisioning_project_id,
          provisioning_region: provisioning_region,
          provisioning_zone: provisioning_zone,
          ephemeral_machine_type: ephemeral_machine_type
        }.transform_values { |user_input| sanitize_value(user_input) }.merge(
          deployment_name: deployment_name,
          gitlab_url: Gitlab.config.gitlab.url
        )

        {
          terraform_script: terraform_template.result_with_hash(locals),
          shell_script: shell_template.result_with_hash(locals)
        }
      end
      strong_memoize_attr :instructions

      def sanitize_value(user_input)
        # Ensure the variable name starts with a letter and only contains letters, digits, underscores, and hyphens
        user_input&.gsub(/[^a-zA-Z0-9_-]/, '_')
      end

      def provisioning_project_id
        params[:provisioning_project_id]
      end

      def provisioning_region
        params[:provisioning_region]
      end

      def provisioning_zone
        params[:provisioning_zone]
      end

      def ephemeral_machine_type
        params[:ephemeral_machine_type]
      end

      def runner_token
        params[:runner_token]
      end
    end
  end
end
