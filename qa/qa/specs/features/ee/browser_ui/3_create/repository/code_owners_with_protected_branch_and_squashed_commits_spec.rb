# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Setup an MR with codeowners file', product_group: :source_code do
      let(:project) { create(:project, :with_readme) }

      let!(:target) do
        create(:commit, project: project, branch: project.default_branch, actions: [
          { action: 'create', file_path: '.gitlab/CODEOWNERS', content: '* @root' }
        ])
      end

      let!(:source) do
        create(:commit, project: project, branch: 'codeowners_test', start_branch: project.default_branch, actions: [
          { action: 'create', file_path: 'test1.txt', content: '1' }
        ])

        create(:commit, project: project, branch: 'codeowners_test', actions: [
          { action: 'create', file_path: 'test2.txt', content: '2' }
        ])
      end

      before do
        Flow::Login.sign_in
      end

      it 'creates a merge request with codeowners file and squashing commits enabled', :blocking, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347672' do
        # The default branch is already protected, and we can't update a protected branch via the API (yet)
        # so we unprotect it first and then protect it again with the desired parameters
        Resource::ProtectedBranch.unprotect_via_api! do |branch|
          branch.project = project
          branch.branch_name = project.default_branch
        end

        create(:protected_branch,
          project: project,
          new_branch: false,
          branch_name: project.default_branch,
          allowed_to_push: { roles: Resource::ProtectedBranch::Roles::NO_ONE },
          allowed_to_merge: { roles: Resource::ProtectedBranch::Roles::MAINTAINERS },
          require_code_owner_approval: true)

        create(:merge_request,
          :no_preparation,
          project: project,
          source_branch: source.branch,
          target_branch: target.branch,
          title: 'merging two commits').visit!

        Page::MergeRequest::Show.perform do |mr|
          mr.mark_to_squash
          mr.merge!

          expect(mr).to be_merged
        end
      end
    end
  end
end
