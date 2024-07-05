# frozen_string_literal: true

module CloudConnector
  class BaseAvailableServiceData
    include Gitlab::Utils::StrongMemoize

    attr_accessor :name, :cut_off_date

    def initialize(name, cut_off_date, add_on_names)
      @name = name
      @cut_off_date = cut_off_date
      @add_on_names = map_duo_pro(add_on_names)
    end

    # Returns whether the service is free to access (no addon purchases is required)
    def free_access?
      cut_off_date.nil? || cut_off_date&.future?
    end

    # Returns true if service is allowed to be used.
    # For provided user, it will check if user is assigned to a proper seat.
    #
    # user - User
    def allowed_for?(user)
      add_on_purchases_assigned_to(user).any?
    end

    # Returns true if service is purchased.
    # For provided namespace, it will check if add-on is purchased for the provided group/project or its ancestors.
    #
    # For SM, it will check if add-on is purchased, by ignoring namespace as AddOns are not purchased per namespace.
    #
    # namespace - Namespace
    def purchased?(namespace = nil)
      add_on_purchases(namespace).any?
    end

    # Returns CloudConnector access JWT token.
    #
    # For Gitlab.com it will self-issue a token with scopes based on provided resource:
    # - For provided user, it will self-issue a token with scopes based on user assigment permissions
    # - For provided namespace, it will self-issue a token with scopes based on add-on purchased permissions
    # - If service has free_access?, it will self-issue a token with all available scopes
    #
    # For SM, it will return :CloudConnector::ServiceAccessToken instance token
    #
    # resource - User or Namespace
    # extra_claims: - extra_claims can be included for self-issued access_token on gitlab.com
    def access_token(_resource = nil, **)
      raise 'Not implemented'
    end

    private

    # TODO: We shold remove this when https://gitlab.com/gitlab-org/gitlab/-/issues/458745 is done
    def map_duo_pro(add_on_names)
      add_on_names&.map { |add_on| add_on == 'duo_pro' ? 'code_suggestions' : add_on } || []
    end

    def add_on_purchases_assigned_to(user)
      cache_key = format(GitlabSubscriptions::UserAddOnAssignment::USER_ADD_ON_ASSIGNMENT_CACHE_KEY, user_id: user.id)

      Rails.cache.fetch(cache_key) do
        add_on_purchases.assigned_to_user(user)
      end
    end

    def add_on_purchases(namespace = nil)
      strong_memoize_with(:add_on_purchases, namespace) do
        results = GitlabSubscriptions::AddOnPurchase
          .by_add_on_name(@add_on_names)
          .active
        results = results.by_namespace(namespace.self_and_ancestor_ids) if namespace

        results
      end
    end
  end
end
