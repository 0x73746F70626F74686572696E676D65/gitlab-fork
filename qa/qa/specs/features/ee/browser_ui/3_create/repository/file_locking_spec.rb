# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'File Locking', product_group: :source_code do
      let(:user_one) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1)
      end

      let(:user_two) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_2, Runtime::Env.gitlab_qa_password_2)
      end

      let(:project) { create(:project, :with_readme, name: 'file_locking') }

      before do
        Flow::Login.sign_in

        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.file_name = 'file'
          push.file_content = SecureRandom.hex(100000)
          push.new_branch = false
        end

        add_to_project user: user_one
        add_to_project user: user_two

        Resource::ProtectedBranch.unprotect_via_api! do |branch|
          branch.project = project
          branch.branch_name = project.default_branch
        end
      end

      it 'locks a directory and tries to push as a second user',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347768' do
        push branch: project.default_branch, file: 'directory/file', as_user: user_one

        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_directory
        click_lock

        expect_error_on_push for_file: 'directory/file', as_user: user_two
        expect_no_error_on_push for_file: 'directory/file', as_user: user_one
      end

      it 'locks a file and tries to push as a second user', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347769' do
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file
        click_lock

        expect_error_on_push as_user: user_two
        expect_no_error_on_push as_user: user_one
      end

      it 'checks file locked by other user to be disabled', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347767' do
        go_to_file
        click_lock
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file

        Page::File::Show.perform do |show|
          expect(show).to have_lock_button_disabled
        end
      end

      it 'creates a merge request and fails to merge', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347770' do
        push branch: 'test', as_user: user_one

        merge_request = create(:merge_request,
          :no_preparation,
          project: project,
          source_branch: 'test',
          target_branch: project.default_branch)

        go_to_file
        click_lock
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        merge_request.visit!

        Page::MergeRequest::Show.perform do |merge_request|
          merge_request.try_to_merge!
          expect(page).to have_text("locked by #{admin_username}", wait: 30)
          expect(merge_request).to have_merge_button
        end
      end

      it 'locks a file and unlocks in list',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347766' do
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file
        click_lock
        project.visit!

        Page::Project::Menu.perform(&:go_to_repository_locked_files)
        EE::Page::Project::PathLocks::Index.perform do |list|
          expect(list).to have_file_with_title 'file'
          list.unlock_file 'file'
        end

        expect_no_error_on_push as_user: user_two
      end

      def go_to_file
        project.visit!
        Page::Project::Show.perform do |project_page|
          project_page.click_file 'file'
        end
      end

      def go_to_directory
        project.visit!
        Page::Project::Show.perform do |project_page|
          project_page.click_file 'directory'
        end
      end

      def click_lock
        Page::File::Show.perform(&:lock)
      end

      def add_to_project(user:)
        Resource::ProjectMember.fabricate_via_api! do |member|
          member.user = user
          member.project = project
          member.access_level = member.level[:developer]
        end
      end

      def push(as_user:, branch: project.default_branch, file: 'file')
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.new_branch = false unless branch != project.default_branch
          push.file_name = file
          push.file_content = SecureRandom.hex(100000)
          push.user = as_user
          push.branch_name = branch
        end
      end

      def expect_error_on_push(as_user:, for_file: 'file')
        expect { push branch: project.default_branch, file: for_file, as_user: as_user }.to raise_error(
          QA::Support::Run::CommandError)
      end

      def expect_no_error_on_push(as_user:, for_file: 'file')
        expect { push branch: project.default_branch, file: for_file, as_user: as_user }.not_to raise_error
      end

      def admin_username
        create(:user, username: Runtime::User.username).name
      end
    end
  end
end
