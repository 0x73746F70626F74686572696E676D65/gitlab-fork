# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Requests
        class VertexAi < Base
          attr_reader :ai_client

          TEMPERATURE = 0.2

          def initialize(user, unit_primitive:, tracking_context: {})
            @ai_client = ::Gitlab::Llm::VertexAi::Client.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context) # rubocop:disable Layout/LineLength -- follow-up
          end

          def request(prompt)
            ai_client.text(
              content: prompt[:prompt],
              parameters: { **default_options.merge(prompt.fetch(:options, {})) }
            )&.dig("predictions", 0, "content").to_s.strip
          end

          private

          def default_options
            ::Gitlab::Llm::VertexAi::Configuration.default_payload_parameters.merge(
              temperature: TEMPERATURE
            )
          end
        end
      end
    end
  end
end
