# frozen_string_literal: true

module EE
  module UserPolicy
    extend ActiveSupport::Concern

    prepended do
      condition(:updating_name_disabled_for_users, scope: :global) do
        ::License.feature_available?(:disable_name_update_for_users) &&
          ::Gitlab::CurrentSettings.current_application_settings.updating_name_disabled_for_users
      end

      condition(:can_remove_self, scope: :subject) do
        @subject.can_remove_self?
      end

      desc "Personal access tokens are disabled"
      condition(:personal_access_tokens_disabled, scope: :global, score: 0) do
        ::Gitlab::CurrentSettings.personal_access_tokens_disabled?
      end

      condition(:disable_private_profiles, scope: :global) do
        ::License.feature_available?(:disable_private_profiles) && ::Feature.enabled?(:disallow_private_profiles) &&
          !::Gitlab::CurrentSettings.current_application_settings.make_profile_private
      end

      rule { can?(:update_user) }.enable :update_name

      rule { updating_name_disabled_for_users & ~admin }.prevent :update_name

      rule { user_is_self & ~can_remove_self }.prevent :destroy_user

      rule { personal_access_tokens_disabled }.prevent :create_user_personal_access_token

      rule { disable_private_profiles & ~admin }.prevent :make_profile_private
    end
  end
end
