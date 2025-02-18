# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Push Rules', product_group: :source_code do
      context 'using non signed commits' do
        before(:context) do
          prepare

          @file_name_limitation = 'denied_file'
          @file_size_limitation = 1
          @authors_email_limitation = %{(#{Regexp.escape(@creator.email)}|#{@root.email})}
          @branch_name_limitation = @project.default_branch
          @needed_phrase_limitation = 'allowed commit'
          @deny_message_phrase_limitation = 'denied commit'

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.fill_file_name(@file_name_limitation)
              push_rules.fill_file_size(@file_size_limitation)
              push_rules.fill_author_email(@authors_email_limitation)
              push_rules.fill_branch_name(@branch_name_limitation)
              push_rules.fill_commit_message_rule(@needed_phrase_limitation)
              push_rules.fill_deny_commit_message_rule(@deny_message_phrase_limitation)
              push_rules.check_prevent_secrets
              push_rules.check_deny_delete_tag
              push_rules.click_submit
            end
          end
        end

        it 'allows an unrestricted push', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347790' do
          expect_no_error_on_push(file: standard_file)
        end

        it 'restricts files by name and size', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347784', quarantine: {
          only: { job: 'ee-qa-browser_ui-3_create' },
          type: :investigating,
          issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/455927'
        } do
          # Note: The file size limits in this test should be lower than the limits in
          # browser_ui/3_create/repository/push_over_http_file_size_spec to prevent
          # the limit set in that test from triggering in this test (which can happen
          # on Staging where the tests are run in parallel).
          # See: https://gitlab.com/gitlab-org/gitlab/-/issues/218620#note_361634705

          large_file = [{
            name: 'file',
            content: SecureRandom.hex(1000000)
          }]
          wrongly_named_file = [{
            name: @file_name_limitation,
            content: SecureRandom.hex(100)
          }]

          expect_error_on_push(
            file: large_file,
            error: 'File "file" is larger than the allowed size of 1 MiB')
          expect_error_on_push(
            file: wrongly_named_file,
            error: Regexp.escape(%(File name #{@file_name_limitation} was prohibited by the pattern "#{@file_name_limitation}")))
        end

        it 'restricts users by email format', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347783' do
          gitlab_user = Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_2, Runtime::Env.gitlab_qa_password_2)
          @project.add_member(gitlab_user, Resource::Members::AccessLevel::MAINTAINER)

          expect_error_on_push(
            file: standard_file,
            user: gitlab_user,
            error: Regexp.escape("Committer's email '#{gitlab_user.email}' does not follow the pattern '#{@authors_email_limitation}'"))
        end

        it 'restricts branches by branch name', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347781' do
          expect_error_on_push(
            file: standard_file,
            branch: 'forbidden_branch',
            error: Regexp.escape("Branch name 'forbidden_branch' does not follow the pattern '#{@branch_name_limitation}'"))
        end

        it 'restricts commit by message format', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347780' do
          expect_no_error_on_push(file: standard_file, commit_message: @needed_phrase_limitation)
          expect_error_on_push(
            file: standard_file,
            commit_message: 'forbidden message',
            error: Regexp.escape("Commit message does not follow the pattern '#{@needed_phrase_limitation}'"))
          expect_error_on_push(
            file: standard_file,
            commit_message: "#{@needed_phrase_limitation} - #{@deny_message_phrase_limitation}",
            error: Regexp.escape("Commit message contains the forbidden pattern '#{@deny_message_phrase_limitation}'"))
        end

        it 'restricts committing files with secrets', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347779' do
          secret_file = [{
            name: 'id_rsa',
            content: SecureRandom.hex(100)
          }]

          expect_error_on_push(
            file: secret_file,
            error: Regexp.escape('File name id_rsa was prohibited by the pattern "id_rsa$"'))
        end

        it 'restricts removal of tag', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347782' do
          tag = create(:tag, project: @project, ref: @project.default_branch, name: "test_tag_#{SecureRandom.hex(8)}")

          expect_error_on_push(file: standard_file, tag: tag.name, error: 'You cannot delete a tag')
        end
      end

      context 'with commits restricted by author email to existing GitLab users' do
        before do
          prepare

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_restrict_author
              push_rules.click_submit
            end
          end
        end

        it 'rejects non-member users', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347812' do
          non_member_user = build(:user,
            username: '',
            password: '',
            name: 'non_member_user',
            email: 'non_member_user@non_member_user.com')

          expect_error_on_push(
            file: standard_file,
            user: non_member_user,
            error: Regexp.escape("Author '#{non_member_user.email}' is not a member of team"))
        end
      end

      context 'with commits restricted to verified emails' do
        before do
          prepare

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_committer_restriction
              push_rules.click_submit
            end
          end
        end

        it 'rejects unverified emails', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347791' do
          expect_no_error_on_push(file: standard_file)
          expect_error_on_push(
            file: standard_file,
            user: @root,
            error: 'You can only push commits if the committer email is one of your own verified emails')
        end
      end

      context 'using signed commits' do
        before do
          prepare

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_reject_unsigned_commits
              push_rules.click_submit
            end
          end

          @gpg = Resource::UserGPG.fabricate_via_api!
        end

        it 'restricts to signed commits', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347785' do
          expect_no_error_on_push(file: standard_file, gpg: @gpg)
          expect_error_on_push(file: standard_file, error: 'Commit must be signed with a GPG key')
        end
      end

      def standard_file
        [{
          name: 'file',
          content: SecureRandom.hex(100)
        }]
      end

      def push(commit_message:, branch:, file:, user:, tag:, gpg:, max_attempts:)
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = @project
          push.commit_message = commit_message
          push.new_branch = branch != @project.default_branch
          push.branch_name = branch
          push.user = user if user != @root
          push.files = file if tag.nil?
          push.tag_name = tag unless tag.nil?
          push.gpg_key_id = gpg.key_id unless gpg.nil?
          push.max_attempts = max_attempts if max_attempts
        end
      end

      def expect_no_error_on_push(file:, commit_message: 'allowed commit', branch: @project.default_branch, user: @creator, tag: nil, gpg: nil)
        expect do
          push commit_message: commit_message, branch: branch, file: file, user: user, tag: tag, gpg: gpg, max_attempts: 3
        end.not_to raise_error
      end

      def expect_error_on_push(file:, commit_message: 'allowed commit', branch: @project.default_branch, user: @creator, tag: nil, gpg: nil, error: nil)
        expect do
          push commit_message: commit_message, branch: branch, file: file, user: user, tag: tag, gpg: gpg, max_attempts: 1
        end.to raise_error(QA::Support::Run::CommandError, /#{error}/)
      end

      def prepare
        Flow::Login.sign_in

        @creator = create(:user, username: Runtime::User.username, password: Runtime::User.password)

        @root = build(:user, username: 'root', name: 'GitLab QA', email: 'root@gitlab.com', password: nil)

        @project = create(:project, name: 'push_rules')

        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = @project
          push.files = standard_file
        end

        @project.visit!

        Page::Project::Menu.perform(&:go_to_repository_settings)
      end
    end
  end
end
