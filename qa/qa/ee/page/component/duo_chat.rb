# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        class DuoChat < QA::Page::Base
          view 'ee/app/assets/javascripts/ai/tanuki_bot/components/app.vue' do
            # components are derived from gitlab/ui
          end

          def send_duo_chat_prompt(prompt)
            fill_element('chat-prompt-input', prompt)
            click_element('paper-airplane-icon')
            wait_for_requests
          end

          def clear_chat_history
            send_duo_chat_prompt('/clean')
          end

          def empty_state?
            has_element?('gl-empty-state-content')
          end

          def latest_response
            find_all('.duo-chat-message p').last.text
          end

          def number_of_messages
            find_all('.duo-chat-message').size
          end
        end
      end
    end
  end
end
