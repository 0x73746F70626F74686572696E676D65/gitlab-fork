# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        override :track_event
        def track_event(event_name, context_hash = {})
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          attributes = context_hash
            .with_indifferent_access
            .slice(*Ai::CodeSuggestionsUsage.attribute_names)
            .merge(event: event_name)

          Ai::CodeSuggestionsUsage.new(attributes).store
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
