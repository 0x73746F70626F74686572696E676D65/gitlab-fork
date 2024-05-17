# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Completions
        class GenerateCubeQuery < Gitlab::Llm::Completions::Base
          def execute
            prompt = ai_prompt_class.new(options[:question]).to_prompt

            response = Gitlab::Llm::VertexAi::Client.new(user,
              unit_primitive: 'generate_cube_query'
            ).code(content: prompt)

            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, resource, response_modifier, options: response_options
            ).execute
          end
        end
      end
    end
  end
end
