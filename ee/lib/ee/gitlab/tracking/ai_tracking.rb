# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        EVENTS = {
          'code_suggestions_requested' => 1,
          'code_suggestions_shown' => 2,
          'code_suggestions_accepted' => 3,
          'code_suggestions_rejected' => 4
        }.freeze

        extend ::Gitlab::Utils::Override

        override :track_event
        def track_event(event_name, context_hash = {})
          return unless EVENTS[event_name]
          return unless ::Feature.enabled?(:ai_tracking_data_gathering) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- this is an ops flag.
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          event_hash = {
            event: EVENTS[event_name],
            timestamp: context_hash[:timestamp] ? DateTime.parse(context_hash[:timestamp]) : Time.current,
            user_id: context_hash[:user]&.id
          }

          ::ClickHouse::WriteBuffer.write_event(event_hash)
        end

        override :track_via_code_suggestions?
        def track_via_code_suggestions?(event_name, user)
          event_name.to_s == 'code_suggestions_requested' &&
            ::Feature.disabled?(:code_suggestions_direct_completions, user)
        end
      end
    end
  end
end
