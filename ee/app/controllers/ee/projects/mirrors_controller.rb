# frozen_string_literal: true

module EE
  module Projects
    module MirrorsController
      extend ::Gitlab::Utils::Override
      extend ActiveSupport::Concern

      override :update_now
      def update_now
        if params[:sync_remote]
          project.update_remote_mirrors
          flash[:notice] = _('The remote repository is being updated...')
        else
          StartPullMirroringService.new(project, current_user, pause_on_hard_failure: false).execute
          flash[:notice] = _('The repository is being updated...')
        end

        redirect_to_repository_settings(project, anchor: 'js-push-remote-settings')
      end

      def mirror_params_attributes
        if can?(current_user, :admin_mirror, project)
          attributes = super
          attributes[0][:remote_mirrors_attributes].push(:mirror_branch_regex)
          attributes + mirror_params_attributes_ee
        else
          super
        end
      end

      private

      override :notice_message
      def notice_message
        if project.mirror?
          _('Mirroring settings were successfully updated. The project is being updated.')
        elsif project.previous_changes.key?('mirror')
          _('Mirroring was successfully disabled.')
        else
          super
        end
      end

      def mirror_params_attributes_ee
        attrs = Projects::UpdateService::PULL_MIRROR_ATTRIBUTES.dup
        attrs.delete(:mirror_user_id) # Cannot be set by the frontend
        attrs.delete(:import_data_attributes) # We need more detail here
        attrs.push(
          import_data_attributes: %i[
            id
            auth_method
            user
            password
            ssh_known_hosts
            regenerate_ssh_private_key
          ]
        )
      end

      override :safe_mirror_params
      def safe_mirror_params
        params = super

        import_data = params[:import_data_attributes]

        if import_data.present?
          # Prevent Rails from destroying the existing import data
          import_data[:id] ||= project.import_data&.id

          # If the known hosts data is being set, store details about who and when
          if import_data[:ssh_known_hosts].present?
            import_data[:ssh_known_hosts_verified_at] = Time.current
            import_data[:ssh_known_hosts_verified_by_id] = current_user.id
          end
        end

        # avoid enable only_protected_branches and mirror_branch_regex at the same time
        remote_mirror_data = params[:remote_mirrors_attributes]
        if remote_mirror_data.present?
          remote_mirror_data.transform_values! do |value|
            format_remote_mirrors_attributes(value)
            value
          end
        end

        params
      end

      # Pass mirror_branch_regex and only_protected_branches at same time will use mirror_branch_regex
      def format_remote_mirrors_attributes(params)
        return unless params.is_a?(ActionController::Parameters)

        params[:only_protected_branches] = false if params[:mirror_branch_regex].present?
        params[:mirror_branch_regex] = nil if params[:only_protected_branches].present?
      end
    end
  end
end
