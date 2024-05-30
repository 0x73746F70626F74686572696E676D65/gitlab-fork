# frozen_string_literal: true

module EE
  module ActiveSession
    module ClassMethods
      def set_marketing_user_cookies(auth, user)
        return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        expiration_time = 2.weeks.from_now
        domain = ::Gitlab.config.gitlab.host

        auth.cookies[:gitlab_user] =
          {
            value: true,
            domain: domain,
            expires: expiration_time
          }

        return if ::Feature.disabled?(:add_gitlab_tier_cookie, ::Feature.current_request)

        tiers = GitlabSubscriptions::CurrentActivePlansForUserFinder.new(user).execute.pluck(:name) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- False positive as limit is defined in finder

        auth.cookies[:gitlab_tier] = {
          value: tiers.presence || false,
          domain: domain,
          expires: expiration_time
        }
      end
    end

    def self.prepended(base)
      base.singleton_class.prepend(ClassMethods)
    end
  end
end
