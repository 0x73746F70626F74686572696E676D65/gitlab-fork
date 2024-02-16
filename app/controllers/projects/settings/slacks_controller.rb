# frozen_string_literal: true

module Projects
  module Settings
    class SlacksController < Projects::ApplicationController
      before_action :handle_oauth_error, only: :slack_auth
      before_action :check_oauth_state, only: :slack_auth

      include ::Integrations::SlackControllerSettings

      before_action :authorize_admin_project!
      before_action :integration, only: [:edit, :update]
      before_action :slack_integration, only: [:edit, :update]

      layout 'project_settings'

      def slack_auth
        result = Projects::SlackApplicationInstallService.new(project, current_user, params).execute

        flash[:alert] = result[:message] if result[:status] == :error

        session[:slack_install_success] = true
        redirect_to_integration_page
      end

      def edit; end

      def update
        if slack_integration.update(slack_integration_params)
          flash[:notice] = 'The project alias was updated successfully'

          redirect_to_integration_page
        else
          render :edit
        end
      end

      private

      def integration
        @integration ||= project.gitlab_slack_application_integration
      end

      def redirect_to_integration_page
        redirect_to edit_project_settings_integration_path(
          project, integration || project.build_gitlab_slack_application_integration
        )
      end

      def check_oauth_state
        render_403 unless valid_authenticity_token?(session, params[:state])

        true
      end

      def handle_oauth_error
        return unless params[:error] == 'access_denied'

        flash[:alert] = 'Access denied'
        redirect_to_integration_page
      end

      def slack_integration_params
        params.require(:slack_integration).permit(:alias)
      end
    end
  end
end
