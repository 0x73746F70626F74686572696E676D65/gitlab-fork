# frozen_string_literal: true

module EE
  module SidebarsHelper
    extend ::Gitlab::Utils::Override

    override :project_sidebar_context_data
    def project_sidebar_context_data(project, user, current_ref, **args)
      super.merge({
        show_promotions: show_promotions?(user),
        show_discover_project_security: show_discover_project_security?(project),
        learn_gitlab_enabled: Onboarding::LearnGitlab.available?(project.namespace, user)
      })
    end

    override :group_sidebar_context_data
    def group_sidebar_context_data(group, user)
      super.merge(
        show_promotions: show_promotions?(user),
        show_discover_group_security: show_discover_group_security?(group)
      )
    end

    override :super_sidebar_nav_panel
    def super_sidebar_nav_panel(nav: nil, project: nil, user: nil, group: nil, current_ref: nil, ref_type: nil)
      if nav == 'security'
        context = ::Sidebars::Context.new(current_user: user, container: nil,
          route_is_active: method(:active_nav_link?))
        ::Sidebars::Security::Panel.new(context)
      else
        super
      end
    end

    override :super_sidebar_context
    def super_sidebar_context(user, group:, project:, panel:)
      show_buy_pipeline_minutes = show_buy_pipeline_minutes?(project, group)

      return super unless show_buy_pipeline_minutes

      root_namespace = root_ancestor_namespace(project, group)

      super.merge({
        pipeline_minutes: {
          show_buy_pipeline_minutes: show_buy_pipeline_minutes,
          show_notification_dot: show_pipeline_minutes_notification_dot?(project, group),
          show_with_subtext: show_buy_pipeline_with_subtext?(project, group),
          buy_pipeline_minutes_path: usage_quotas_path(root_namespace),
          tracking_attrs: {
            'track-action': 'click_buy_ci_minutes',
            'track-label': root_namespace.actual_plan_name,
            'track-property': 'user_dropdown'
          },
          notification_dot_attrs: {
            'data-track-action': 'render',
            'data-track-label': 'show_buy_ci_minutes_notification',
            'data-track-property': current_user.namespace.actual_plan_name
          },
          callout_attrs: {
            feature_id: ::Ci::RunnersHelper::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT,
            dismiss_endpoint: callouts_path
          }
        }
      })
    end
  end
end
