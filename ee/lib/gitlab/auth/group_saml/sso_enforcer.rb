# frozen_string_literal: true

module Gitlab
  module Auth
    module GroupSaml
      class SsoEnforcer
        DEFAULT_SESSION_TIMEOUT = 1.day

        class << self
          def sessions_time_remaining_for_expiry
            SsoState.active_saml_sessions.map do |id, last_sign_in_at|
              expires_at = last_sign_in_at + DEFAULT_SESSION_TIMEOUT
              # expires_at is DateTime; convert to Time; Time - Time yields a Float
              time_remaining_for_expiry = expires_at.to_time - Time.current
              { provider_id: id, time_remaining: time_remaining_for_expiry }
            end
          end

          def access_restricted?(user:, resource:, session_timeout: DEFAULT_SESSION_TIMEOUT)
            group = resource.is_a?(::Group) ? resource : resource.group

            return false unless group

            saml_provider = group.root_saml_provider

            return false unless saml_provider
            return false if user_authorized?(user, resource)

            new(saml_provider, user: user, session_timeout: session_timeout).access_restricted?
          end

          # Given an array of groups or subgroups, return an array
          # of root groups that are access restricted for the user
          def access_restricted_groups(groups, user: nil)
            return [] unless groups.any?

            ::Preloaders::GroupRootAncestorPreloader.new(groups, [:saml_provider]).execute
            root_ancestors = groups.map(&:root_ancestor).uniq

            root_ancestors.select do |root_ancestor|
              new(root_ancestor.saml_provider, user: user).access_restricted?
            end
          end

          private

          def user_authorized?(user, resource)
            return true if resource.public? && !resource_member?(resource, user)
            return true if resource.is_a?(::Group) && resource.root? && resource.owned_by?(user)

            false
          end

          def resource_member?(resource, user)
            user && user.is_a?(::User) && resource.member?(user)
          end
        end

        attr_reader :saml_provider, :user, :session_timeout

        def initialize(saml_provider, user: nil, session_timeout: DEFAULT_SESSION_TIMEOUT)
          @saml_provider = saml_provider
          @user = user
          @session_timeout = session_timeout
        end

        def update_session
          SsoState.new(saml_provider.id).update_active(DateTime.now)
        end

        def active_session?
          SsoState.new(saml_provider.id).active_since?(session_timeout.ago)
        end

        def access_restricted?
          return false if user_authorized?

          saml_enforced? && !active_session?
        end

        private

        def saml_enforced?
          return true if saml_provider&.enforced_sso?
          return false unless user && group
          return false unless saml_provider&.enabled? && group.licensed_feature_available?(:group_saml)

          user.group_sso?(group)
        end

        def user_authorized?
          return false unless user

          if Feature.enabled?(:fix_sso_enforcement_for_web_activity, user) && !in_context_of_user_web_activity?
            return true
          end

          return true if user.can_read_all_resources?

          false
        end

        def in_context_of_user_web_activity?
          Gitlab::Session.current &&
            Gitlab::Session.current.dig('warden.user.user.key', 0, 0) == user.id
        end

        def group
          saml_provider&.group
        end
      end
    end
  end
end
