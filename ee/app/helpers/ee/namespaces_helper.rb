# frozen_string_literal: true

module EE
  module NamespacesHelper
    extend ::Gitlab::Utils::Override

    def ci_minutes_report(quota_report)
      content_tag(:span, class: "shared_runners_limit_#{quota_report.status}") do
        "#{quota_report.used} / #{quota_report.limit}"
      end
    end

    def ci_minutes_progress_bar(percent)
      status =
        if percent >= 95
          'danger'
        elsif percent >= 70
          'warning'
        else
          'success'
        end

      width = [percent, 100].min

      options = {
        class: "progress-bar bg-#{status}",
        style: "width: #{width}%;"
      }

      content_tag :div, class: 'progress' do
        content_tag :div, nil, options
      end
    end

    def temporary_storage_increase_visible?(namespace)
      return false unless ::Gitlab::CurrentSettings.enforce_namespace_storage_limit?
      return false unless ::Feature.enabled?(:temporary_storage_increase, namespace)

      current_user.can?(:admin_namespace, namespace.root_ancestor)
    end

    def buy_additional_minutes_path(namespace)
      return EE::SUBSCRIPTIONS_MORE_MINUTES_URL if use_customers_dot_for_addon_path?(namespace)

      buy_minutes_subscriptions_path(selected_group: namespace.root_ancestor.id)
    end

    def buy_addon_target_attr(namespace)
      use_customers_dot_for_addon_path?(namespace) ? '_blank' : '_self'
    end

    def buy_storage_path(namespace)
      return EE::SUBSCRIPTIONS_MORE_STORAGE_URL if use_customers_dot_for_addon_path?(namespace)

      buy_storage_subscriptions_path(selected_group: namespace.id)
    end

    def buy_storage_url(namespace)
      return EE::SUBSCRIPTIONS_MORE_STORAGE_URL if use_customers_dot_for_addon_path?(namespace)

      buy_storage_subscriptions_url(selected_group: namespace.id)
    end

    def show_minute_limit_banner?(namespace)
      return false unless ::Gitlab.com? && ::Feature.enabled?(:show_minute_limit_banner, namespace.root_ancestor, default_enabled: :yaml) # rubocop:disable Layout/LineLength

      namespace.root_ancestor.free_plan? && !minute_limit_banner_dismissed?
    end

    override :pipeline_usage_quota_app_data
    def pipeline_usage_quota_app_data(namespace)
      return super unless ::Gitlab::CurrentSettings.should_check_namespace_plan?

      minutes_quota_presenter = ::Ci::Minutes::QuotaPresenter.new(namespace.ci_minutes_quota)

      super.merge(
        ci_minutes: {
          any_project_enabled: minutes_quota_presenter.any_project_enabled?.to_s
        },
        buy_additional_minutes_path: buy_additional_minutes_path(namespace),
        buy_additional_minutes_target: buy_addon_target_attr(namespace)
      )
    end

    private

    def use_customers_dot_for_addon_path?(namespace)
      namespace.user_namespace?
    end
  end
end
