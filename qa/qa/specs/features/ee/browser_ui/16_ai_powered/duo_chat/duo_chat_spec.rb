# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', product_group: :duo_chat do
    describe 'Duo Chat' do
      shared_examples 'Duo Chat' do |testcase|
        it 'gets a response back from Duo Chat', testcase: testcase do
          QA::EE::Page::Component::DuoChat.perform do |duo_chat|
            duo_chat.open_duo_chat
            duo_chat.clear_chat_history
            duo_chat.send_duo_chat_prompt('hi')

            Support::Waiter.wait_until(message: 'Wait for Duo Chat response') do
              duo_chat.number_of_messages > 1
            end

            expect(duo_chat.has_response?(expected_response)).to be_truthy,
              "Expected \"#{expected_response}\" within Duo Chat response."
          end
        end
      end

      before do
        Flow::Login.sign_in
      end

      context 'when initiating Duo Chat' do
        context 'on GitLab.com', :external_ai_provider,
          only: { pipeline: %i[staging staging-canary canary production] } do
          let(:expected_response) { 'GitLab' }

          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/441192'
        end

        context 'on Self-managed', :orchestrated, :ai_gateway do
          # As an orchestrated test we use an ai-gateway with a fake model, so we can assert part of the prompt
          # https://gitlab.com/gitlab-org/gitlab/-/blob/481a3af0ded95cb24fc1e34b004d104c72ed95e4/ee/lib/gitlab/llm/chain/agents/zero_shot/executor.rb#L229-229
          let(:expected_response) { 'Question: the input question you must answer' }

          it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/464684'
        end
      end
    end
  end
end
