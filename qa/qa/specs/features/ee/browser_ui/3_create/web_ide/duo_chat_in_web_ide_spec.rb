# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Create', :external_ai_provider, product_group: :ide do
    describe 'Duo Chat in Web IDE' do
      let(:project) { create(:project, :with_readme, name: 'webide-duo-chat-project') }

      before do
        Flow::Login.sign_in
        project.visit!
        Page::Project::Show.perform(&:open_web_ide!)
        Page::Project::WebIDE::VSCode.perform(&:wait_for_ide_to_load)
      end

      context 'when initiating Duo Chat' do
        it 'returns a response to a simple request', only: { pipeline: %i[staging staging-canary canary production] },
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/443762' do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.open_duo_chat
            ide.within_vscode_duo_chat do
              QA::EE::Page::Component::DuoChat.perform do |duo_chat|
                duo_chat.clear_chat_history
                expect(duo_chat).to be_empty_state

                duo_chat.send_duo_chat_prompt('hi')
                expect(duo_chat.has_response?('GitLab')).to be_truthy, 'Expected "GitLab" within Duo Chat response.'
              end
            end
          end
        end
      end
    end
  end
end
