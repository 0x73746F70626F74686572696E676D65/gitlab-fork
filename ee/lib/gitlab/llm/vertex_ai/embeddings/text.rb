# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Embeddings
        class Text
          def initialize(text, user:, tracking_context:, unit_primitive:)
            @text = text
            @user = user
            @tracking_context = tracking_context
            @unit_primitive = unit_primitive
          end

          attr_reader :user, :text, :tracking_context, :unit_primitive

          def execute
            result = client.text_embeddings(content: text)

            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings.new(result)

            raise StandardError, response_modifier.errors if response_modifier.errors.any?

            if !result.success? || response_modifier.response_body.nil?
              raise StandardError, "Could not generate embedding: '#{result}'"
            end

            response_modifier.response_body
          end

          private

          def client
            ::Gitlab::Llm::VertexAi::Client.new(user,
              unit_primitive: unit_primitive,
              tracking_context: tracking_context)
          end
        end
      end
    end
  end
end
