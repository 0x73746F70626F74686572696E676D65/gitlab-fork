# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', product_group: :secret_detection,
    only: { pipeline: %w[staging-canary staging canary production] } do
    describe 'Secret Push Protection' do
      let!(:project) do
        create(:project, :with_readme, name: 'secret-push-project', description: 'Secret Push Protection Project')
      end

      let(:reverse_token_prefix) { 'taplg' }
      let(:test_token) { '-JUST20LETTERSANDNUMB' }

      it 'blocks commit when enabled when token is detected',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/468475' do
        Flow::Login.sign_in_unless_signed_in

        project.visit!
        Page::Project::Menu.perform(&:go_to_security_configuration)

        Page::Project::Secure::ConfigurationForm.perform do |config_form|
          expect(config_form).to have_false_secret_detection_status

          config_form.enable_secret_detection

          expect(config_form).to have_true_secret_detection_status
        end

        Git::Repository.perform do |repository|
          repository.uri = project.repository_http_location.uri
          repository.use_default_credentials
          repository.default_branch = project.default_branch
          repository.clone
          repository.configure_identity('GitLab QA', 'root@gitlab.com')
          repository.commit_file("new-file", reverse_token_prefix.reverse + test_token, "Add token file")
          # rubocop:disable Layout/LineLength -- Long regular expression to capture the error from the git commit
          expect do
            repository.push_changes
          end.to raise_error.with_message(%r{.*(PUSH BLOCKED: Secrets detected in code changes )[\s\S]*(Secret push protection found the following secrets in commit)[\s\S]*(GitLab Personal Access Token)[\s\S]*(To push your changes you must remove the identified secrets.)})
          # rubocop:enable Layout/LineLength
        end
      end
    end
  end
end
