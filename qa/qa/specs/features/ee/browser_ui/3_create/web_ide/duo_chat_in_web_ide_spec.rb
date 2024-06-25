# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Create', product_group: :ide do
    describe 'Duo Chat in Web IDE' do
      shared_examples 'Duo Chat' do |testcase|
        it 'gets a response back from Duo Chat', testcase: testcase do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.open_duo_chat
            ide.within_vscode_duo_chat do
              QA::EE::Page::Component::DuoChat.perform do |duo_chat|
                duo_chat.clear_chat_history
                expect(duo_chat).to be_empty_state

                duo_chat.send_duo_chat_prompt('hi')
                expect(duo_chat.has_response?(expected_response)).to be_truthy,
                  "Expected '#{expected_response}' within Duo Chat response."
              end
            end
          end
        end
      end

      let(:project) { create(:project, :with_readme, name: 'webide-duo-chat-project') }

      before do
        Flow::Login.sign_in
        project.visit!
        Page::Project::Show.perform(&:open_web_ide!)
        Page::Project::WebIDE::VSCode.perform(&:wait_for_ide_to_load)
      end

      context 'on GitLab.com', :external_ai_provider,
        only: { pipeline: %i[staging staging-canary canary production] } do
        let(:expected_response) { 'GitLab' }

        it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/443762'
      end

      context 'on Self-managed', :orchestrated, :ai_gateway do
        # As an orchestrated test we use an ai-gateway with a fake model, so we can assert part of the prompt
        # https://gitlab.com/gitlab-org/gitlab/-/blob/481a3af0ded95cb24fc1e34b004d104c72ed95e4/ee/lib/gitlab/llm/chain/agents/zero_shot/executor.rb#L229-229
        let(:expected_response) { 'Question: the input question you must answer' }

        it_behaves_like 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/468854'
      end
    end
  end
end
