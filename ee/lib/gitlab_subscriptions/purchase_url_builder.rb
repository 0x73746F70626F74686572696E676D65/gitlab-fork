# frozen_string_literal: true

module GitlabSubscriptions
  class PurchaseUrlBuilder
    def initialize(current_user:, plan_id:, namespace:)
      @current_user = current_user
      @plan_id = plan_id
      @namespace = namespace
    end

    def customers_dot_flow?
      Feature.enabled?(:migrate_purchase_flows_for_existing_customers, current_user) &&
        namespace.present? && valid_billing_account?
    end

    def build(params = {})
      if customers_dot_flow?
        customers_dot_purchase_flow_url(params)
      else
        gitlab_purchase_flow_url(params)
      end
    end

    private

    attr_reader :current_user, :plan_id, :namespace

    def customers_dot_purchase_flow_url(params)
      query = params.merge({ plan_id: plan_id, gl_namespace_id: namespace.id }).compact

      Gitlab::Utils.add_url_parameters(Gitlab::Routing.url_helpers.subscription_portal_new_subscription_url, query)
    end

    def gitlab_purchase_flow_url(params)
      if gitlab_purchase_flow_supported?
        Gitlab::Routing.url_helpers.new_subscriptions_path(
          plan_id: plan_id,
          namespace_id: namespace.id,
          source: params[:source]
        )
      else
        customers_dot_purchase_flow_url(params)
      end
    end

    def gitlab_purchase_flow_supported?
      # the GitLab flow requires the user to already have a last name.
      # This can be removed once https://gitlab.com/gitlab-org/gitlab/-/issues/298715 is complete.
      current_user.last_name.present? && namespace.group_namespace?
    end

    def valid_billing_account?
      response = Gitlab::SubscriptionPortal::Client.get_billing_account_details(current_user)
      response[:success] && response.dig(:billing_account_details, "billingAccount", "zuoraAccountName").present?
    end
  end
end
