# frozen_string_literal: true

module Mutations
  module Projects
    class ProjectSettingsUpdate < BaseMutation
      graphql_name 'ProjectSettingsUpdate'

      include FindsProject
      include Gitlab::Utils::StrongMemoize

      authorize :admin_project

      argument :full_path,
        GraphQL::Types::ID,
        required: true,
        description: 'Full Path of the project the settings belong to.'

      argument :duo_features_enabled,
        GraphQL::Types::Boolean,
        required: true,
        description: 'Indicates whether GitLab Duo features are enabled for the project.'

      field :project_settings,
        Types::Projects::SettingType,
        null: false,
        description: 'Project settings after mutation.'

      def resolve(full_path:, **args)
        raise raise_resource_not_available_error! unless allowed?

        project = authorized_find!(full_path)
        ::Projects::UpdateService.new(project, current_user, { project_setting_attributes: args }).execute

        {
          project_settings: project.project_setting,
          errors: errors_on_object(project.project_setting)
        }
      end

      private

      def allowed?
        # TODO clean up via https://gitlab.com/gitlab-org/gitlab/-/issues/440546
        return true if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
        return false unless ::License.feature_available?(:code_suggestions)

        ::CloudConnector::AvailableServices.find_by_name(:code_suggestions).purchased?
      end
    end
  end
end
