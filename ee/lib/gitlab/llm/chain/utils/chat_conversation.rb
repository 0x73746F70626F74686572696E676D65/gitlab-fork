# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Utils
        class ChatConversation
          LAST_N_CONVERSATIONS = 50

          def initialize(user)
            @user = user
          end

          # We save a maximum of 50 chat history messages
          # We save a max of 20k chars for each message prompt (~5k
          # tokens)
          # Response from Anthropic is max of 4096 tokens
          # So the max tokens we would ever send 9k * 50 = 450k tokens.
          # Max context window is 200k.
          # For now, no truncating actually happening here but we should
          # do that to make sure we stay under the limit.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/452608
          def truncated_conversation_list(last_n: LAST_N_CONVERSATIONS)
            messages = successful_conversations
            messages = sorted_by_timestamp(messages)

            return [] if messages.blank?

            messages.last(last_n).map do |message, _|
              { role: message.role.to_sym, content: message.content }
            end
          end

          private

          attr_reader :user

          # agent_version is deprecated, Chat conversation doesn't have this param anymore
          # include only messages with successful response and reorder
          # messages so each question is followed by its answer
          def successful_conversations
            ChatStorage.new(user, nil)
              .last_conversation
              .reject { |message| message.errors.present? }
              .group_by(&:request_id)
              .select { |_uuid, messages| messages.size > 1 }
          end

          def sorted_by_timestamp(conversations)
            conversations.values.sort_by { |messages| messages.first.timestamp }.flatten
          end
        end
      end
    end
  end
end
