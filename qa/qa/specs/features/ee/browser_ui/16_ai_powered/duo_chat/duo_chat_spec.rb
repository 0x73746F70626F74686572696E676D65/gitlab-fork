# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', :external_ai_provider, product_group: :duo_chat do
    describe 'Duo Chat' do
      before do
        Flow::Login.sign_in
      end

      context 'when initiating Duo Chat' do
        # We only run on environments with Duo Chat integration
        it 'returns a response to a simple request', only: { pipeline: %i[staging staging-canary canary production] },
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/441192' do
          Page::Main::Menu.perform(&:open_duo_chat)

          QA::EE::Page::Component::DuoChat.perform do |duo_chat|
            duo_chat.clear_chat_history
            duo_chat.send_duo_chat_prompt('hi')
            expect do
              duo_chat.latest_response
            end.to eventually_match(/GitLab/).within(max_duration: 30)
          end
        end
      end
    end
  end
end
