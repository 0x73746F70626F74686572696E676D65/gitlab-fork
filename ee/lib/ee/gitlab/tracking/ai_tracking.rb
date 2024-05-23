# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        override :track_event
        def track_event(event_name, context_hash = {})
          return unless ::Feature.enabled?(:ai_tracking_data_gathering) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- this is an ops flag.
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          Ai::CodeSuggestionsUsage.new(**context_hash.merge(event: event_name)).store
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
