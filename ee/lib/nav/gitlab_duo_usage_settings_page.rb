# frozen_string_literal: true

module Nav
  module GitlabDuoUsageSettingsPage
    include ::GitlabSubscriptions::SubscriptionHelper
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    def show_gitlab_duo_usage_menu_item?(group)
      group.usage_quotas_enabled? &&
        show_gitlab_duo_usage_app?(group) &&
        ::Feature.enabled?(:gitlab_duo_usage_menu_item, group)
    end

    def show_gitlab_duo_usage_app?(group)
      gitlab_com_subscription? &&
        gitlab_duo_available?(group) &&
        (!group.has_free_or_no_subscription? || group.subscription_add_on_purchases.active.for_gitlab_duo_pro.any?) &&
        License.feature_available?(:code_suggestions)
    end
  end
end
