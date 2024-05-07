# frozen_string_literal: true

module EE
  module Users
    module GroupCalloutsHelper
      UNLIMITED_MEMBERS_DURING_TRIAL_ALERT = 'unlimited_members_during_trial_alert'
      ALL_SEATS_USED_ALERT = 'all_seats_used_alert'
      COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT = 'compliance_framework_settings_moved_callout'

      def show_compliance_framework_settings_moved_callout?(group)
        !user_dismissed_for_group(COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT, group)
      end

      def show_unlimited_members_during_trial_alert?(group)
        ::Namespaces::FreeUserCap::Enforcement.new(group).qualified_namespace? &&
          ::Namespaces::FreeUserCap.owner_access?(user: current_user, namespace: group) &&
          group.trial_active? &&
          !user_dismissed_for_group(UNLIMITED_MEMBERS_DURING_TRIAL_ALERT, group)
      end
    end
  end
end
