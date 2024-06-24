# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        POSSIBLE_MODELS = [Ai::CodeSuggestionsUsage, Ai::DuoChatEvent].freeze

        override :track_event
        def track_event(event_name, context_hash = {})
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }

          return unless matched_model

          attributes = context_hash.with_indifferent_access
                                   .merge(event: event_name)
                                   .slice(*matched_model.attribute_names)

          matched_model.new(attributes).store
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
