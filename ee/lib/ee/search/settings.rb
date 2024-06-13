# frozen_string_literal: true

module EE
  module Search
    module Settings
      extend ActiveSupport::Concern

      extend ::Gitlab::Utils::Override

      override :project_general_settings
      def project_general_settings(project)
        return super unless project.licensed_feature_available?(:issuable_default_templates)

        super.concat [
          { text: _("Default description template for issues"),
            href: edit_project_path(project, anchor: 'js-issue-settings') }
        ]
      end

      override :project_repository_settings
      def project_repository_settings(project)
        settings = super

        if project.licensed_feature_available?(:target_branch_rules)
          settings.push(
            { text: _("Protected branches"),
              href: project_settings_repository_path(project, anchor: 'js-protected-branches-settings') },
            { text: _("Protected tags"),
              href: project_settings_repository_path(project, anchor: 'js-protected-tags-settings') }
          )
        end

        if project.licensed_feature_available?(:push_rules)
          settings.push({
            text: s_('PushRule|Push rules'),
            href: project_settings_repository_path(project, anchor: 'js-push-rules')
          })
        end

        settings
      end

      override :project_merge_request_settings
      def project_merge_request_settings(project)
        settings = super

        if project.licensed_feature_available?(:target_branch_rules)
          settings.push({
            text: _("Merge request branch workflow"),
            href: project_settings_merge_requests_path(project, anchor: 'target-branch-rules')
          })
        end

        if project.licensed_feature_available?(:merge_request_approvers)
          settings.push({
            text: _("Merge request approvals"),
            href: project_settings_merge_requests_path(project, anchor: 'js-merge-request-approval-settings')
          })
        end

        settings
      end

      override :project_ci_cd_settings
      def project_ci_cd_settings(project)
        settings = super

        if project.licensed_feature_available?(:protected_environments)
          settings.push({
            text: _("Protected environments"),
            href: project_settings_ci_cd_path(project, anchor: 'js-protected-environments-settings')
          })
        end

        if project.licensed_feature_available?(:auto_rollback)
          settings.push({
            text: _("Automatic deployment rollbacks"),
            href: project_settings_ci_cd_path(project, anchor: 'auto-rollback-settings')
          })
        end

        if project.licensed_feature_available?(:ci_project_subscriptions)
          settings.push({
            text: _("Pipeline subscriptions"),
            href: project_settings_ci_cd_path(project, anchor: 'pipeline-subscriptions')
          })
        end

        settings
      end

      override :project_monitor_settings
      def project_monitor_settings(project)
        return super unless project.licensed_feature_available?(:status_page)

        super.concat [
          { text: s_("StatusPage|Status page"),
            href: project_settings_operations_path(project, anchor: 'status-page') }
        ]
      end
    end
  end
end
