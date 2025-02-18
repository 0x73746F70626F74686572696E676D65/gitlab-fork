# frozen_string_literal: true

module EE
  module NamespacesHelper
    extend ::Gitlab::Utils::Override

    def ci_minutes_report(usage_report)
      content_tag(:span, class: "shared_runners_limit_#{usage_report.status}") do
        "#{usage_report.used} / #{usage_report.limit}"
      end
    end

    def buy_additional_minutes_path(namespace)
      return more_minutes_url if use_customers_dot_for_addon_path?(namespace)

      buy_minutes_subscriptions_path(selected_group: namespace.root_ancestor.id)
    end

    def buy_additional_minutes_url(namespace)
      return more_minutes_url if use_customers_dot_for_addon_path?(namespace)

      buy_minutes_subscriptions_url(selected_group: namespace.root_ancestor.id)
    end

    def buy_addon_target_attr(namespace)
      use_customers_dot_for_addon_path?(namespace) ? '_blank' : '_self'
    end

    def buy_storage_path(namespace)
      return purchase_storage_url if use_customers_dot_for_addon_path?(namespace)

      buy_storage_subscriptions_path(selected_group: namespace.root_ancestor.id)
    end

    def buy_storage_url(namespace)
      return purchase_storage_url if use_customers_dot_for_addon_path?(namespace)

      buy_storage_subscriptions_url(selected_group: namespace.root_ancestor.id)
    end

    override :pipeline_usage_app_data
    def pipeline_usage_app_data(namespace)
      minutes_usage = namespace.ci_minutes_usage
      minutes_usage_presenter = ::Ci::Minutes::UsagePresenter.new(minutes_usage)

      # EE data
      ci_minutes = {
        any_project_enabled: minutes_usage_presenter.any_project_enabled?.to_s,
        last_reset_date: minutes_usage.reset_date,
        display_minutes_available_data: minutes_usage_presenter.display_minutes_available_data?.to_s,
        monthly_minutes_used: minutes_usage_presenter.monthly_minutes_report.used,
        monthly_minutes_used_percentage: minutes_usage_presenter.monthly_percent_used,
        monthly_minutes_limit: minutes_usage_presenter.monthly_minutes_report.limit
      }

      return super.merge(ci_minutes: ci_minutes) unless ::Gitlab::CurrentSettings.should_check_namespace_plan?

      # SaaS data
      ci_minutes.merge!({
        purchased_minutes_used: minutes_usage_presenter.purchased_minutes_report.used,
        purchased_minutes_used_percentage: minutes_usage_presenter.purchased_percent_used,
        purchased_minutes_limit: minutes_usage_presenter.purchased_minutes_report.limit
      })

      super.merge(
        ci_minutes: ci_minutes,
        buy_additional_minutes_path: buy_additional_minutes_path(namespace),
        buy_additional_minutes_target: buy_addon_target_attr(namespace)
      )
    end

    override :storage_usage_app_data
    def storage_usage_app_data(namespace)
      per_project_storage_limit = namespace.actual_repository_size_limit
      namespace_storage_limit = namespace.actual_limits.storage_size_limit.megabytes
      is_in_namespace_limits_pre_enforcement = ::Namespaces::Storage::Enforcement.in_pre_enforcement_phase?(namespace)

      unless ::Gitlab::CurrentSettings.should_check_namespace_plan?
        # EE SM app data
        return super.merge({
          enforcement_type: namespace.root_storage_size.enforcement_type,
          per_project_storage_limit: per_project_storage_limit
        })
      end

      # EE SaaS app data
      super.merge({
        namespace_plan_name: namespace.actual_plan_name.capitalize,
        purchase_storage_url: buy_storage_path(namespace),
        buy_addon_target_attr: buy_addon_target_attr(namespace),
        per_project_storage_limit: per_project_storage_limit,
        namespace_storage_limit: namespace_storage_limit,
        enforcement_type: namespace.root_storage_size.enforcement_type,
        is_in_namespace_limits_pre_enforcement: is_in_namespace_limits_pre_enforcement.to_s,
        total_repository_size_excess: namespace.total_repository_size_excess
      })
    end

    def purchase_storage_url
      ::Gitlab::Routing.url_helpers.subscription_portal_more_storage_url
    end

    private

    def more_minutes_url
      ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url
    end

    def use_customers_dot_for_addon_path?(namespace)
      namespace.user_namespace?
    end
  end
end
