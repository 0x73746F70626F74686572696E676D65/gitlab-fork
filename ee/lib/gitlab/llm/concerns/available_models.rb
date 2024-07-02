# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module AvailableModels
        CLAUDE_3_5_SONNET = 'claude-3-5-sonnet-20240620'
        CLAUDE_3_SONNET = 'claude-3-sonnet-20240229'
        CLAUDE_3_HAIKU = 'claude-3-haiku-20240307'
        CLAUDE_2_1 = 'claude-2.1'
        DEFAULT_INSTANT_MODEL = 'claude-instant-1.2'

        VERTEX_MODEL_CHAT = 'chat-bison'
        VERTEX_MODEL_CODE = 'code-bison'
        VERTEX_MODEL_CODECHAT = 'codechat-bison'
        VERTEX_MODEL_TEXT = 'text-bison'
        ANTHROPIC_MODELS = [CLAUDE_2_1, CLAUDE_3_SONNET, CLAUDE_3_5_SONNET, CLAUDE_3_HAIKU,
          DEFAULT_INSTANT_MODEL].freeze
        VERTEX_MODELS = [VERTEX_MODEL_CHAT, VERTEX_MODEL_CODECHAT, VERTEX_MODEL_CODE, VERTEX_MODEL_TEXT].freeze

        AVAILABLE_MODELS = {
          anthropic: ANTHROPIC_MODELS,
          vertex: VERTEX_MODELS
        }.freeze
      end
    end
  end
end
