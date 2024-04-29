# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module AllowedParams
        ANTHROPIC_PARAMS = %i[temperature max_tokens_to_sample stop_sequences].freeze
        VERTEX_PARAMS = %i[temperature maxOutputTokens topK topP].freeze

        ALLOWED_PARAMS = {
          anthropic: ANTHROPIC_PARAMS,
          vertex: VERTEX_PARAMS
        }.freeze
      end
    end
  end
end
